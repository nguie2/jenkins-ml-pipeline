"""
Alibi Detect Configuration for ML Model Bias Detection
Author: Nguie Angoue Jean Roch Junior
Email: nguierochjunior@gmail.com
"""

import logging
import numpy as np
import pandas as pd
from typing import Dict, List, Any, Optional, Tuple, Union
from dataclasses import dataclass
from enum import Enum

import alibi_detect
from alibi_detect.utils.saving import save_detector, load_detector
from alibi_detect import bias

logger = logging.getLogger(__name__)


class BiasMetric(Enum):
    """Supported bias detection metrics."""
    DEMOGRAPHIC_PARITY = "demographic_parity"
    EQUALIZED_ODDS = "equalized_odds"
    EQUAL_OPPORTUNITY = "equal_opportunity"
    CALIBRATION = "calibration"
    COUNTERFACTUAL_FAIRNESS = "counterfactual_fairness"


@dataclass
class BiasDetectionResult:
    """Result of bias detection analysis."""
    overall_bias_score: float
    bias_detected: bool
    threshold_exceeded: bool
    metric_scores: Dict[str, float]
    group_scores: Dict[str, float]
    recommendations: List[str]
    metadata: Dict[str, Any]


class MLModelBiasDetector:
    """Comprehensive bias detection for ML models using Alibi Detect."""
    
    def __init__(
        self,
        model_name: str,
        protected_attributes: List[str],
        threshold: float = 0.05,
        metrics: Optional[List[BiasMetric]] = None
    ):
        """Initialize bias detector.
        
        Args:
            model_name: Name of the model being monitored.
            protected_attributes: List of protected attribute column names.
            threshold: Bias threshold above which alerts are triggered.
            metrics: List of bias metrics to compute. If None, uses all available.
        """
        self.model_name = model_name
        self.protected_attributes = protected_attributes
        self.threshold = threshold
        self.metrics = metrics or list(BiasMetric)
        
        # Initialize detectors
        self.detectors = {}
        self._initialize_detectors()
        
        logger.info(f"Initialized bias detector for model: {model_name}")
    
    def _initialize_detectors(self) -> None:
        """Initialize bias detection algorithms."""
        # Note: Alibi Detect bias detection is conceptual here
        # In practice, you would use specific bias detection libraries
        # or implement custom bias metrics
        
        for metric in self.metrics:
            detector_config = self._get_detector_config(metric)
            self.detectors[metric.value] = detector_config
    
    def _get_detector_config(self, metric: BiasMetric) -> Dict[str, Any]:
        """Get configuration for specific bias metric."""
        configs = {
            BiasMetric.DEMOGRAPHIC_PARITY: {
                "name": "Demographic Parity",
                "description": "Ensures equal positive prediction rates across groups",
                "formula": "P(Y_hat=1|A=0) = P(Y_hat=1|A=1)",
                "threshold": self.threshold
            },
            BiasMetric.EQUALIZED_ODDS: {
                "name": "Equalized Odds",
                "description": "Ensures equal TPR and FPR across groups",
                "formula": "P(Y_hat=1|Y=y,A=0) = P(Y_hat=1|Y=y,A=1) for y in {0,1}",
                "threshold": self.threshold
            },
            BiasMetric.EQUAL_OPPORTUNITY: {
                "name": "Equal Opportunity",
                "description": "Ensures equal TPR across groups",
                "formula": "P(Y_hat=1|Y=1,A=0) = P(Y_hat=1|Y=1,A=1)",
                "threshold": self.threshold
            },
            BiasMetric.CALIBRATION: {
                "name": "Calibration",
                "description": "Ensures equal calibration across groups",
                "formula": "P(Y=1|Y_hat=v,A=0) = P(Y=1|Y_hat=v,A=1) for all v",
                "threshold": self.threshold
            },
            BiasMetric.COUNTERFACTUAL_FAIRNESS: {
                "name": "Counterfactual Fairness",
                "description": "Ensures predictions would be same in counterfactual world",
                "formula": "P(Y_hat=1|A=0,U=u) = P(Y_hat=1|A=1,U=u) for all u",
                "threshold": self.threshold
            }
        }
        return configs[metric]
    
    def detect_bias(
        self,
        predictions: np.ndarray,
        true_labels: np.ndarray,
        protected_attributes: pd.DataFrame,
        prediction_probabilities: Optional[np.ndarray] = None
    ) -> BiasDetectionResult:
        """Detect bias in model predictions.
        
        Args:
            predictions: Model predictions (0/1 for binary classification).
            true_labels: True labels.
            protected_attributes: DataFrame with protected attribute values.
            prediction_probabilities: Model prediction probabilities (optional).
        
        Returns:
            BiasDetectionResult with comprehensive bias analysis.
        """
        try:
            # Validate inputs
            self._validate_inputs(predictions, true_labels, protected_attributes)
            
            # Compute bias metrics
            metric_scores = {}
            group_scores = {}
            
            for metric in self.metrics:
                score = self._compute_bias_metric(
                    metric, predictions, true_labels, protected_attributes, prediction_probabilities
                )
                metric_scores[metric.value] = score
                
                # Compute group-specific scores
                group_score = self._compute_group_bias(
                    metric, predictions, true_labels, protected_attributes
                )
                group_scores.update(group_score)
            
            # Calculate overall bias score
            overall_bias_score = np.mean(list(metric_scores.values()))
            bias_detected = overall_bias_score > self.threshold
            
            # Generate recommendations
            recommendations = self._generate_recommendations(
                metric_scores, group_scores, bias_detected
            )
            
            # Create metadata
            metadata = {
                "model_name": self.model_name,
                "sample_size": len(predictions),
                "protected_attributes": self.protected_attributes,
                "metrics_computed": [m.value for m in self.metrics],
                "threshold": self.threshold,
                "timestamp": pd.Timestamp.now().isoformat()
            }
            
            result = BiasDetectionResult(
                overall_bias_score=overall_bias_score,
                bias_detected=bias_detected,
                threshold_exceeded=bias_detected,
                metric_scores=metric_scores,
                group_scores=group_scores,
                recommendations=recommendations,
                metadata=metadata
            )
            
            logger.info(f"Bias detection completed for {self.model_name}. "
                       f"Overall score: {overall_bias_score:.4f}")
            
            return result
            
        except Exception as e:
            logger.error(f"Bias detection failed for {self.model_name}: {str(e)}")
            raise
    
    def _validate_inputs(
        self,
        predictions: np.ndarray,
        true_labels: np.ndarray,
        protected_attributes: pd.DataFrame
    ) -> None:
        """Validate input data for bias detection."""
        if len(predictions) != len(true_labels):
            raise ValueError("Predictions and true labels must have same length")
        
        if len(predictions) != len(protected_attributes):
            raise ValueError("Predictions and protected attributes must have same length")
        
        for attr in self.protected_attributes:
            if attr not in protected_attributes.columns:
                raise ValueError(f"Protected attribute '{attr}' not found in data")
        
        if not np.all(np.isin(predictions, [0, 1])):
            raise ValueError("Predictions must be binary (0 or 1)")
        
        if not np.all(np.isin(true_labels, [0, 1])):
            raise ValueError("True labels must be binary (0 or 1)")
    
    def _compute_bias_metric(
        self,
        metric: BiasMetric,
        predictions: np.ndarray,
        true_labels: np.ndarray,
        protected_attributes: pd.DataFrame,
        prediction_probabilities: Optional[np.ndarray] = None
    ) -> float:
        """Compute specific bias metric."""
        
        if metric == BiasMetric.DEMOGRAPHIC_PARITY:
            return self._demographic_parity(predictions, protected_attributes)
        
        elif metric == BiasMetric.EQUALIZED_ODDS:
            return self._equalized_odds(predictions, true_labels, protected_attributes)
        
        elif metric == BiasMetric.EQUAL_OPPORTUNITY:
            return self._equal_opportunity(predictions, true_labels, protected_attributes)
        
        elif metric == BiasMetric.CALIBRATION:
            if prediction_probabilities is None:
                logger.warning("Calibration requires prediction probabilities, skipping")
                return 0.0
            return self._calibration(prediction_probabilities, true_labels, protected_attributes)
        
        elif metric == BiasMetric.COUNTERFACTUAL_FAIRNESS:
            # This would require causal inference, simplified here
            return self._counterfactual_fairness(predictions, protected_attributes)
        
        else:
            raise ValueError(f"Unknown bias metric: {metric}")
    
    def _demographic_parity(
        self,
        predictions: np.ndarray,
        protected_attributes: pd.DataFrame
    ) -> float:
        """Compute demographic parity bias score."""
        max_bias = 0.0
        
        for attr in self.protected_attributes:
            groups = protected_attributes[attr].unique()
            if len(groups) < 2:
                continue
            
            group_rates = []
            for group in groups:
                mask = protected_attributes[attr] == group
                if np.sum(mask) > 0:
                    positive_rate = np.mean(predictions[mask])
                    group_rates.append(positive_rate)
            
            if len(group_rates) >= 2:
                bias_score = max(group_rates) - min(group_rates)
                max_bias = max(max_bias, bias_score)
        
        return max_bias
    
    def _equalized_odds(
        self,
        predictions: np.ndarray,
        true_labels: np.ndarray,
        protected_attributes: pd.DataFrame
    ) -> float:
        """Compute equalized odds bias score."""
        max_bias = 0.0
        
        for attr in self.protected_attributes:
            groups = protected_attributes[attr].unique()
            if len(groups) < 2:
                continue
            
            tpr_scores = []
            fpr_scores = []
            
            for group in groups:
                mask = protected_attributes[attr] == group
                if np.sum(mask) > 0:
                    group_preds = predictions[mask]
                    group_labels = true_labels[mask]
                    
                    # True Positive Rate
                    if np.sum(group_labels == 1) > 0:
                        tpr = np.mean(group_preds[group_labels == 1])
                        tpr_scores.append(tpr)
                    
                    # False Positive Rate
                    if np.sum(group_labels == 0) > 0:
                        fpr = np.mean(group_preds[group_labels == 0])
                        fpr_scores.append(fpr)
            
            # Compute bias as max difference in TPR and FPR
            if len(tpr_scores) >= 2:
                tpr_bias = max(tpr_scores) - min(tpr_scores)
                max_bias = max(max_bias, tpr_bias)
            
            if len(fpr_scores) >= 2:
                fpr_bias = max(fpr_scores) - min(fpr_scores)
                max_bias = max(max_bias, fpr_bias)
        
        return max_bias
    
    def _equal_opportunity(
        self,
        predictions: np.ndarray,
        true_labels: np.ndarray,
        protected_attributes: pd.DataFrame
    ) -> float:
        """Compute equal opportunity bias score."""
        max_bias = 0.0
        
        for attr in self.protected_attributes:
            groups = protected_attributes[attr].unique()
            if len(groups) < 2:
                continue
            
            tpr_scores = []
            
            for group in groups:
                mask = protected_attributes[attr] == group
                if np.sum(mask) > 0:
                    group_preds = predictions[mask]
                    group_labels = true_labels[mask]
                    
                    # True Positive Rate for positive class only
                    if np.sum(group_labels == 1) > 0:
                        tpr = np.mean(group_preds[group_labels == 1])
                        tpr_scores.append(tpr)
            
            if len(tpr_scores) >= 2:
                bias_score = max(tpr_scores) - min(tpr_scores)
                max_bias = max(max_bias, bias_score)
        
        return max_bias
    
    def _calibration(
        self,
        prediction_probabilities: np.ndarray,
        true_labels: np.ndarray,
        protected_attributes: pd.DataFrame
    ) -> float:
        """Compute calibration bias score."""
        max_bias = 0.0
        
        # Bin predictions into deciles
        bins = np.linspace(0, 1, 11)
        
        for attr in self.protected_attributes:
            groups = protected_attributes[attr].unique()
            if len(groups) < 2:
                continue
            
            group_calibrations = []
            
            for group in groups:
                mask = protected_attributes[attr] == group
                if np.sum(mask) > 0:
                    group_probs = prediction_probabilities[mask]
                    group_labels = true_labels[mask]
                    
                    calibration_errors = []
                    for i in range(len(bins) - 1):
                        bin_mask = (group_probs >= bins[i]) & (group_probs < bins[i + 1])
                        if np.sum(bin_mask) > 0:
                            predicted_prob = np.mean(group_probs[bin_mask])
                            actual_prob = np.mean(group_labels[bin_mask])
                            calibration_errors.append(abs(predicted_prob - actual_prob))
                    
                    if calibration_errors:
                        group_calibrations.append(np.mean(calibration_errors))
            
            if len(group_calibrations) >= 2:
                bias_score = max(group_calibrations) - min(group_calibrations)
                max_bias = max(max_bias, bias_score)
        
        return max_bias
    
    def _counterfactual_fairness(
        self,
        predictions: np.ndarray,
        protected_attributes: pd.DataFrame
    ) -> float:
        """Compute counterfactual fairness bias score (simplified)."""
        # This is a simplified version - real counterfactual fairness
        # requires causal inference and counterfactual data generation
        return self._demographic_parity(predictions, protected_attributes)
    
    def _compute_group_bias(
        self,
        metric: BiasMetric,
        predictions: np.ndarray,
        true_labels: np.ndarray,
        protected_attributes: pd.DataFrame
    ) -> Dict[str, float]:
        """Compute bias scores for individual groups."""
        group_scores = {}
        
        for attr in self.protected_attributes:
            groups = protected_attributes[attr].unique()
            
            for group in groups:
                mask = protected_attributes[attr] == group
                if np.sum(mask) > 0:
                    group_key = f"{attr}_{group}_{metric.value}"
                    
                    # Compute metric-specific score for this group
                    if metric == BiasMetric.DEMOGRAPHIC_PARITY:
                        score = np.mean(predictions[mask])
                    elif metric in [BiasMetric.EQUALIZED_ODDS, BiasMetric.EQUAL_OPPORTUNITY]:
                        if np.sum(true_labels[mask] == 1) > 0:
                            score = np.mean(predictions[mask][true_labels[mask] == 1])
                        else:
                            score = 0.0
                    else:
                        score = 0.0
                    
                    group_scores[group_key] = score
        
        return group_scores
    
    def _generate_recommendations(
        self,
        metric_scores: Dict[str, float],
        group_scores: Dict[str, float],
        bias_detected: bool
    ) -> List[str]:
        """Generate recommendations based on bias detection results."""
        recommendations = []
        
        if not bias_detected:
            recommendations.append("✅ No significant bias detected. Continue monitoring.")
            return recommendations
        
        # Identify most problematic metrics
        problematic_metrics = [
            metric for metric, score in metric_scores.items()
            if score > self.threshold
        ]
        
        for metric in problematic_metrics:
            if metric == "demographic_parity":
                recommendations.append(
                    "⚠️ Demographic parity violation detected. Consider rebalancing training data "
                    "or applying fairness constraints during training."
                )
            elif metric == "equalized_odds":
                recommendations.append(
                    "⚠️ Equalized odds violation detected. Consider post-processing techniques "
                    "to equalize true positive and false positive rates across groups."
                )
            elif metric == "equal_opportunity":
                recommendations.append(
                    "⚠️ Equal opportunity violation detected. Focus on equalizing true positive "
                    "rates across protected groups."
                )
            elif metric == "calibration":
                recommendations.append(
                    "⚠️ Calibration bias detected. Consider recalibrating model predictions "
                    "separately for each protected group."
                )
        
        # General recommendations
        recommendations.extend([
            "🔄 Retrain model with fairness-aware algorithms",
            "📊 Collect more representative training data",
            "🎯 Apply bias mitigation techniques (preprocessing, in-processing, or post-processing)",
            "🔍 Conduct regular bias audits with domain experts",
            "📖 Review model decisions with affected stakeholders"
        ])
        
        return recommendations
    
    def save_detector(self, filepath: str) -> None:
        """Save bias detector configuration."""
        config = {
            "model_name": self.model_name,
            "protected_attributes": self.protected_attributes,
            "threshold": self.threshold,
            "metrics": [m.value for m in self.metrics],
            "detectors": self.detectors
        }
        
        import pickle
        with open(filepath, 'wb') as f:
            pickle.dump(config, f)
        
        logger.info(f"Bias detector saved to {filepath}")
    
    @classmethod
    def load_detector(cls, filepath: str) -> 'MLModelBiasDetector':
        """Load bias detector from file."""
        import pickle
        with open(filepath, 'rb') as f:
            config = pickle.load(f)
        
        metrics = [BiasMetric(m) for m in config["metrics"]]
        detector = cls(
            model_name=config["model_name"],
            protected_attributes=config["protected_attributes"],
            threshold=config["threshold"],
            metrics=metrics
        )
        detector.detectors = config["detectors"]
        
        logger.info(f"Bias detector loaded from {filepath}")
        return detector


def create_sample_bias_detection():
    """Create sample bias detection for demonstration."""
    # Create sample data
    np.random.seed(42)
    n_samples = 1000
    
    # Features
    age = np.random.normal(40, 15, n_samples)
    income = np.random.normal(50000, 20000, n_samples)
    
    # Protected attributes
    gender = np.random.choice(['M', 'F'], n_samples)
    race = np.random.choice(['White', 'Black', 'Hispanic', 'Asian'], n_samples)
    
    # Introduce bias: different approval rates by gender
    base_approval_prob = 1 / (1 + np.exp(-(age * 0.02 + income * 0.00001 - 2)))
    gender_bias = np.where(gender == 'M', 0.1, -0.1)
    approval_prob = np.clip(base_approval_prob + gender_bias, 0, 1)
    
    # Generate predictions and true labels
    predictions = np.random.binomial(1, approval_prob, n_samples)
    true_labels = np.random.binomial(1, base_approval_prob, n_samples)  # Unbiased ground truth
    
    # Create DataFrames
    protected_df = pd.DataFrame({
        'gender': gender,
        'race': race
    })
    
    return predictions, true_labels, protected_df


if __name__ == "__main__":
    # Example usage
    detector = MLModelBiasDetector(
        model_name="loan_approval_model",
        protected_attributes=["gender", "race"],
        threshold=0.05
    )
    
    # Generate sample data
    predictions, true_labels, protected_attributes = create_sample_bias_detection()
    
    # Detect bias
    results = detector.detect_bias(predictions, true_labels, protected_attributes)
    
    print("=== Bias Detection Results ===")
    print(f"Overall Bias Score: {results.overall_bias_score:.4f}")
    print(f"Bias Detected: {results.bias_detected}")
    print(f"Threshold Exceeded: {results.threshold_exceeded}")
    
    print("\n=== Metric Scores ===")
    for metric, score in results.metric_scores.items():
        print(f"{metric}: {score:.4f}")
    
    print("\n=== Recommendations ===")
    for rec in results.recommendations[:3]:  # Show first 3 recommendations
        print(rec)
    
    print(f"\n=== Metadata ===")
    print(f"Sample Size: {results.metadata['sample_size']}")
    print(f"Protected Attributes: {results.metadata['protected_attributes']}")
    print(f"Timestamp: {results.metadata['timestamp']}") 