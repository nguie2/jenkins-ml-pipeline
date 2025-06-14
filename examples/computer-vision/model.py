#!/usr/bin/env python3
"""
Computer Vision Model Example for Jenkins ML Pipeline
Author: Nguie Angoue Jean Roch Junior
Email: nguierochjunior@gmail.com

This example demonstrates:
- Image classification using TensorFlow/Keras
- Model training with validation
- Bias detection and fairness assessment
- Model versioning and registry integration
- OpenTelemetry instrumentation
"""

import os
import sys
import json
import logging
import numpy as np
import pandas as pd
from datetime import datetime
from typing import Dict, List, Tuple, Optional

# ML Libraries
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report, confusion_matrix
import cv2
from PIL import Image

# MLOps Libraries
import mlflow
import mlflow.tensorflow
from opentelemetry import trace
from opentelemetry.exporter.jaeger.thrift import JaegerExporter
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

# Data Validation
import great_expectations as ge
from great_expectations.core import ExpectationSuite

# Bias Detection
from alibi_detect.cd import TabularDrift
from alibi_detect.utils.saving import save_detector, load_detector

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Configure OpenTelemetry
trace.set_tracer_provider(TracerProvider())
tracer = trace.get_tracer(__name__)

jaeger_exporter = JaegerExporter(
    agent_host_name="jaeger-agent.monitoring.svc.cluster.local",
    agent_port=6831,
)

span_processor = BatchSpanProcessor(jaeger_exporter)
trace.get_tracer_provider().add_span_processor(span_processor)


class ComputerVisionModel:
    """
    Computer Vision Model for image classification with MLOps integration
    """
    
    def __init__(self, model_name: str = "cv-classifier", version: str = "1.0.0"):
        self.model_name = model_name
        self.version = version
        self.model = None
        self.history = None
        self.metrics = {}
        
        # MLflow configuration
        mlflow.set_tracking_uri("http://mlflow.jenkins.svc.cluster.local:5000")
        mlflow.set_experiment(f"{model_name}-experiment")
        
    @tracer.start_as_current_span("data_preparation")
    def prepare_data(self, data_path: str, img_size: Tuple[int, int] = (224, 224)) -> Tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
        """
        Prepare image data for training
        """
        logger.info(f"Preparing data from {data_path}")
        
        # For demonstration, create synthetic data
        # In production, this would load real image datasets
        num_samples = 1000
        num_classes = 10
        
        # Generate synthetic image data
        X = np.random.rand(num_samples, img_size[0], img_size[1], 3)
        y = np.random.randint(0, num_classes, num_samples)
        
        # Convert to categorical
        y_categorical = keras.utils.to_categorical(y, num_classes)
        
        # Split data
        X_train, X_test, y_train, y_test = train_test_split(
            X, y_categorical, test_size=0.2, random_state=42, stratify=y
        )
        
        logger.info(f"Data prepared: Train={X_train.shape}, Test={X_test.shape}")
        return X_train, X_test, y_train, y_test
    
    @tracer.start_as_current_span("data_validation")
    def validate_data(self, X_train: np.ndarray, y_train: np.ndarray) -> bool:
        """
        Validate data quality using Great Expectations
        """
        logger.info("Validating data quality")
        
        try:
            # Convert to DataFrame for validation
            df = pd.DataFrame({
                'image_shape_0': [X_train.shape[1]] * len(X_train),
                'image_shape_1': [X_train.shape[2]] * len(X_train),
                'image_channels': [X_train.shape[3]] * len(X_train),
                'label_sum': np.sum(y_train, axis=1)
            })
            
            # Create Great Expectations dataset
            ge_df = ge.from_pandas(df)
            
            # Define expectations
            ge_df.expect_column_values_to_be_between('image_shape_0', 200, 300)
            ge_df.expect_column_values_to_be_between('image_shape_1', 200, 300)
            ge_df.expect_column_values_to_equal('image_channels', 3)
            ge_df.expect_column_values_to_equal('label_sum', 1.0)
            
            # Validate
            validation_result = ge_df.validate()
            
            if validation_result.success:
                logger.info("Data validation passed")
                return True
            else:
                logger.error("Data validation failed")
                return False
                
        except Exception as e:
            logger.error(f"Data validation error: {str(e)}")
            return False
    
    @tracer.start_as_current_span("model_building")
    def build_model(self, input_shape: Tuple[int, int, int], num_classes: int) -> keras.Model:
        """
        Build CNN model architecture
        """
        logger.info("Building CNN model")
        
        model = keras.Sequential([
            # Convolutional layers
            layers.Conv2D(32, (3, 3), activation='relu', input_shape=input_shape),
            layers.MaxPooling2D((2, 2)),
            layers.Conv2D(64, (3, 3), activation='relu'),
            layers.MaxPooling2D((2, 2)),
            layers.Conv2D(128, (3, 3), activation='relu'),
            layers.MaxPooling2D((2, 2)),
            
            # Dense layers
            layers.Flatten(),
            layers.Dropout(0.5),
            layers.Dense(512, activation='relu'),
            layers.Dropout(0.3),
            layers.Dense(num_classes, activation='softmax')
        ])
        
        # Compile model
        model.compile(
            optimizer='adam',
            loss='categorical_crossentropy',
            metrics=['accuracy', 'precision', 'recall']
        )
        
        logger.info(f"Model built with {model.count_params()} parameters")
        return model
    
    @tracer.start_as_current_span("model_training")
    def train_model(self, X_train: np.ndarray, y_train: np.ndarray, 
                   X_val: np.ndarray, y_val: np.ndarray, epochs: int = 10) -> None:
        """
        Train the model with MLflow tracking
        """
        logger.info("Starting model training")
        
        with mlflow.start_run():
            # Log parameters
            mlflow.log_param("epochs", epochs)
            mlflow.log_param("batch_size", 32)
            mlflow.log_param("optimizer", "adam")
            mlflow.log_param("model_architecture", "CNN")
            
            # Build model
            self.model = self.build_model(X_train.shape[1:], y_train.shape[1])
            
            # Callbacks
            callbacks = [
                keras.callbacks.EarlyStopping(patience=3, restore_best_weights=True),
                keras.callbacks.ReduceLROnPlateau(factor=0.2, patience=2)
            ]
            
            # Train model
            self.history = self.model.fit(
                X_train, y_train,
                validation_data=(X_val, y_val),
                epochs=epochs,
                batch_size=32,
                callbacks=callbacks,
                verbose=1
            )
            
            # Log metrics
            final_accuracy = self.history.history['val_accuracy'][-1]
            final_loss = self.history.history['val_loss'][-1]
            
            mlflow.log_metric("final_accuracy", final_accuracy)
            mlflow.log_metric("final_loss", final_loss)
            
            # Log model
            mlflow.tensorflow.log_model(self.model, "model")
            
            logger.info(f"Training completed. Final accuracy: {final_accuracy:.4f}")
    
    @tracer.start_as_current_span("model_evaluation")
    def evaluate_model(self, X_test: np.ndarray, y_test: np.ndarray) -> Dict:
        """
        Evaluate model performance
        """
        logger.info("Evaluating model")
        
        # Predictions
        y_pred = self.model.predict(X_test)
        y_pred_classes = np.argmax(y_pred, axis=1)
        y_true_classes = np.argmax(y_test, axis=1)
        
        # Calculate metrics
        test_loss, test_accuracy, test_precision, test_recall = self.model.evaluate(
            X_test, y_test, verbose=0
        )
        
        # F1 Score
        f1_score = 2 * (test_precision * test_recall) / (test_precision + test_recall)
        
        # Classification report
        class_report = classification_report(
            y_true_classes, y_pred_classes, output_dict=True
        )
        
        # Confusion matrix
        conf_matrix = confusion_matrix(y_true_classes, y_pred_classes)
        
        self.metrics = {
            'test_accuracy': test_accuracy,
            'test_precision': test_precision,
            'test_recall': test_recall,
            'test_f1_score': f1_score,
            'test_loss': test_loss,
            'classification_report': class_report,
            'confusion_matrix': conf_matrix.tolist()
        }
        
        logger.info(f"Model evaluation completed. Accuracy: {test_accuracy:.4f}")
        return self.metrics
    
    @tracer.start_as_current_span("bias_detection")
    def detect_bias(self, X_train: np.ndarray, X_test: np.ndarray, 
                   protected_attributes: Optional[List[str]] = None) -> Dict:
        """
        Detect bias in model predictions
        """
        logger.info("Detecting model bias")
        
        try:
            # For demonstration, create synthetic protected attributes
            # In production, these would be real demographic features
            n_train, n_test = len(X_train), len(X_test)
            
            # Simulate protected attributes (e.g., age groups, gender)
            train_protected = np.random.choice(['group_a', 'group_b'], n_train)
            test_protected = np.random.choice(['group_a', 'group_b'], n_test)
            
            # Get predictions
            train_pred = self.model.predict(X_train)
            test_pred = self.model.predict(X_test)
            
            # Calculate bias metrics
            bias_metrics = {}
            
            for group in ['group_a', 'group_b']:
                train_mask = train_protected == group
                test_mask = test_protected == group
                
                if np.sum(train_mask) > 0 and np.sum(test_mask) > 0:
                    group_train_acc = np.mean(
                        np.argmax(train_pred[train_mask], axis=1) == 
                        np.argmax(X_train[train_mask], axis=1)
                    )
                    group_test_acc = np.mean(
                        np.argmax(test_pred[test_mask], axis=1) == 
                        np.argmax(X_test[test_mask], axis=1)
                    )
                    
                    bias_metrics[f'{group}_train_accuracy'] = group_train_acc
                    bias_metrics[f'{group}_test_accuracy'] = group_test_acc
            
            # Calculate fairness metrics
            if len(bias_metrics) >= 4:
                demographic_parity = abs(
                    bias_metrics['group_a_test_accuracy'] - 
                    bias_metrics['group_b_test_accuracy']
                )
                bias_metrics['demographic_parity_difference'] = demographic_parity
                bias_metrics['is_fair'] = demographic_parity < 0.1  # 10% threshold
            
            logger.info("Bias detection completed")
            return bias_metrics
            
        except Exception as e:
            logger.error(f"Bias detection error: {str(e)}")
            return {'error': str(e)}
    
    @tracer.start_as_current_span("model_deployment")
    def save_model(self, model_path: str) -> None:
        """
        Save model for deployment
        """
        logger.info(f"Saving model to {model_path}")
        
        # Create directory if it doesn't exist
        os.makedirs(os.path.dirname(model_path), exist_ok=True)
        
        # Save model
        self.model.save(model_path)
        
        # Save metadata
        metadata = {
            'model_name': self.model_name,
            'version': self.version,
            'timestamp': datetime.now().isoformat(),
            'metrics': self.metrics,
            'framework': 'tensorflow',
            'input_shape': list(self.model.input_shape[1:]),
            'output_shape': list(self.model.output_shape[1:])
        }
        
        metadata_path = os.path.join(os.path.dirname(model_path), 'metadata.json')
        with open(metadata_path, 'w') as f:
            json.dump(metadata, f, indent=2)
        
        logger.info("Model saved successfully")
    
    def generate_model_card(self) -> str:
        """
        Generate model card for documentation
        """
        model_card = f"""
# Model Card: {self.model_name} v{self.version}

## Model Details
- **Model Type**: Convolutional Neural Network (CNN)
- **Framework**: TensorFlow/Keras
- **Version**: {self.version}
- **Date**: {datetime.now().strftime('%Y-%m-%d')}
- **Author**: Nguie Angoue Jean Roch Junior

## Intended Use
- **Primary Use**: Image classification
- **Primary Users**: ML Engineers, Data Scientists
- **Out-of-Scope Uses**: Not suitable for medical diagnosis or safety-critical applications

## Performance Metrics
- **Accuracy**: {self.metrics.get('test_accuracy', 'N/A'):.4f}
- **Precision**: {self.metrics.get('test_precision', 'N/A'):.4f}
- **Recall**: {self.metrics.get('test_recall', 'N/A'):.4f}
- **F1 Score**: {self.metrics.get('test_f1_score', 'N/A'):.4f}

## Training Data
- **Dataset**: Synthetic image data (for demonstration)
- **Size**: 1000 samples
- **Classes**: 10 categories
- **Split**: 80% train, 20% test

## Ethical Considerations
- Bias detection performed during training
- Fairness metrics calculated across demographic groups
- Regular monitoring recommended for production deployment

## Limitations
- Trained on synthetic data for demonstration purposes
- Performance may vary on real-world data
- Requires validation on target domain before production use
        """
        return model_card


def main():
    """
    Main training pipeline
    """
    logger.info("Starting Computer Vision ML Pipeline")
    
    # Initialize model
    cv_model = ComputerVisionModel("cv-classifier", "1.0.0")
    
    try:
        # Prepare data
        X_train, X_test, y_train, y_test = cv_model.prepare_data("/tmp/data")
        
        # Validate data
        if not cv_model.validate_data(X_train, y_train):
            raise ValueError("Data validation failed")
        
        # Split training data for validation
        X_train_split, X_val, y_train_split, y_val = train_test_split(
            X_train, y_train, test_size=0.2, random_state=42
        )
        
        # Train model
        cv_model.train_model(X_train_split, y_train_split, X_val, y_val, epochs=5)
        
        # Evaluate model
        metrics = cv_model.evaluate_model(X_test, y_test)
        logger.info(f"Model metrics: {metrics}")
        
        # Detect bias
        bias_metrics = cv_model.detect_bias(X_train, X_test)
        logger.info(f"Bias metrics: {bias_metrics}")
        
        # Save model
        model_path = "/tmp/models/cv-classifier/model.h5"
        cv_model.save_model(model_path)
        
        # Generate model card
        model_card = cv_model.generate_model_card()
        with open("/tmp/models/cv-classifier/MODEL_CARD.md", "w") as f:
            f.write(model_card)
        
        logger.info("ML Pipeline completed successfully")
        
        # Return success status for Jenkins
        return 0
        
    except Exception as e:
        logger.error(f"Pipeline failed: {str(e)}")
        return 1


if __name__ == "__main__":
    exit_code = main()
    sys.exit(exit_code) 