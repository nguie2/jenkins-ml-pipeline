"""
Great Expectations Configuration for ML Pipeline Data Validation
Author: Nguie Angoue Jean Roch Junior
Email: nguierochjunior@gmail.com
"""

import os
import logging
from typing import Dict, List, Any, Optional
from pathlib import Path

import pandas as pd
import great_expectations as gx
from great_expectations.core.expectation_configuration import ExpectationConfiguration
from great_expectations.core.expectation_suite import ExpectationSuite
from great_expectations.data_context import DataContext
from great_expectations.exceptions import DataContextError

logger = logging.getLogger(__name__)


class MLDataValidator:
    """Data validation using Great Expectations for ML pipelines."""
    
    def __init__(self, context_root_dir: Optional[str] = None):
        """Initialize the data validator.
        
        Args:
            context_root_dir: Root directory for Great Expectations context.
                            If None, uses current directory.
        """
        self.context_root_dir = context_root_dir or os.getcwd()
        self.context = self._initialize_context()
        
    def _initialize_context(self) -> DataContext:
        """Initialize or load Great Expectations data context."""
        try:
            # Try to load existing context
            context = gx.get_context(context_root_dir=self.context_root_dir)
            logger.info("Loaded existing Great Expectations context")
        except DataContextError:
            # Create new context if none exists
            context = gx.get_context(
                context_root_dir=self.context_root_dir,
                create_if_not_exists=True
            )
            logger.info("Created new Great Expectations context")
        
        return context
    
    def create_ml_expectation_suite(
        self, 
        suite_name: str,
        data_schema: Dict[str, Any]
    ) -> ExpectationSuite:
        """Create an expectation suite for ML data validation.
        
        Args:
            suite_name: Name for the expectation suite.
            data_schema: Schema definition for the data including column types,
                        ranges, and validation rules.
        
        Returns:
            Created expectation suite.
        """
        # Create or get expectation suite
        try:
            suite = self.context.get_expectation_suite(suite_name)
            logger.info(f"Loaded existing expectation suite: {suite_name}")
        except:
            suite = self.context.create_expectation_suite(suite_name)
            logger.info(f"Created new expectation suite: {suite_name}")
        
        # Clear existing expectations
        suite.expectations = []
        
        # Add basic data quality expectations
        self._add_basic_expectations(suite, data_schema)
        
        # Add ML-specific expectations
        self._add_ml_expectations(suite, data_schema)
        
        # Save the suite
        self.context.save_expectation_suite(suite)
        
        return suite
    
    def _add_basic_expectations(
        self, 
        suite: ExpectationSuite, 
        data_schema: Dict[str, Any]
    ) -> None:
        """Add basic data quality expectations."""
        
        # Expect table to exist and have rows
        suite.add_expectation(
            ExpectationConfiguration(
                expectation_type="expect_table_row_count_to_be_between",
                kwargs={"min_value": 1, "max_value": None}
            )
        )
        
        # Column existence and types
        for column, config in data_schema.get("columns", {}).items():
            # Expect column to exist
            suite.add_expectation(
                ExpectationConfiguration(
                    expectation_type="expect_column_to_exist",
                    kwargs={"column": column}
                )
            )
            
            # Expect correct data type
            if "type" in config:
                suite.add_expectation(
                    ExpectationConfiguration(
                        expectation_type="expect_column_values_to_be_of_type",
                        kwargs={"column": column, "type_": config["type"]}
                    )
                )
            
            # Null value constraints
            if config.get("nullable", True) is False:
                suite.add_expectation(
                    ExpectationConfiguration(
                        expectation_type="expect_column_values_to_not_be_null",
                        kwargs={"column": column}
                    )
                )
            
            # Value range constraints
            if "min_value" in config or "max_value" in config:
                suite.add_expectation(
                    ExpectationConfiguration(
                        expectation_type="expect_column_values_to_be_between",
                        kwargs={
                            "column": column,
                            "min_value": config.get("min_value"),
                            "max_value": config.get("max_value")
                        }
                    )
                )
            
            # Categorical value constraints
            if "allowed_values" in config:
                suite.add_expectation(
                    ExpectationConfiguration(
                        expectation_type="expect_column_values_to_be_in_set",
                        kwargs={
                            "column": column,
                            "value_set": config["allowed_values"]
                        }
                    )
                )
    
    def _add_ml_expectations(
        self, 
        suite: ExpectationSuite, 
        data_schema: Dict[str, Any]
    ) -> None:
        """Add ML-specific expectations."""
        
        # Feature distribution expectations
        for column, config in data_schema.get("columns", {}).items():
            if config.get("feature_type") == "numerical":
                # Check for statistical properties
                suite.add_expectation(
                    ExpectationConfiguration(
                        expectation_type="expect_column_mean_to_be_between",
                        kwargs={
                            "column": column,
                            "min_value": config.get("expected_mean_min"),
                            "max_value": config.get("expected_mean_max")
                        }
                    )
                )
                
                suite.add_expectation(
                    ExpectationConfiguration(
                        expectation_type="expect_column_stdev_to_be_between",
                        kwargs={
                            "column": column,
                            "min_value": config.get("expected_std_min"),
                            "max_value": config.get("expected_std_max")
                        }
                    )
                )
        
        # Target variable expectations
        target_column = data_schema.get("target_column")
        if target_column:
            target_config = data_schema["columns"][target_column]
            
            # Class distribution for classification
            if target_config.get("task_type") == "classification":
                expected_classes = target_config.get("expected_classes", [])
                if expected_classes:
                    suite.add_expectation(
                        ExpectationConfiguration(
                            expectation_type="expect_column_values_to_be_in_set",
                            kwargs={
                                "column": target_column,
                                "value_set": expected_classes
                            }
                        )
                    )
                
                # Class balance expectations
                min_class_ratio = target_config.get("min_class_ratio", 0.01)
                suite.add_expectation(
                    ExpectationConfiguration(
                        expectation_type="expect_column_proportion_of_unique_values_to_be_between",
                        kwargs={
                            "column": target_column,
                            "min_value": min_class_ratio,
                            "max_value": 1.0
                        }
                    )
                )
        
        # Data freshness expectations
        if "timestamp_column" in data_schema:
            timestamp_col = data_schema["timestamp_column"]
            max_age_days = data_schema.get("max_data_age_days", 30)
            
            suite.add_expectation(
                ExpectationConfiguration(
                    expectation_type="expect_column_max_to_be_between",
                    kwargs={
                        "column": timestamp_col,
                        "min_value": pd.Timestamp.now() - pd.Timedelta(days=max_age_days),
                        "max_value": pd.Timestamp.now()
                    }
                )
            )
        
        # Duplicate detection
        if data_schema.get("check_duplicates", True):
            suite.add_expectation(
                ExpectationConfiguration(
                    expectation_type="expect_table_row_count_to_equal_other_table",
                    kwargs={
                        "other_table_name": "deduplicated_table"
                    }
                )
            )
    
    def validate_data(
        self, 
        data: pd.DataFrame, 
        suite_name: str,
        checkpoint_name: Optional[str] = None
    ) -> Dict[str, Any]:
        """Validate data against an expectation suite.
        
        Args:
            data: DataFrame to validate.
            suite_name: Name of the expectation suite to use.
            checkpoint_name: Optional checkpoint name for validation.
        
        Returns:
            Validation results dictionary.
        """
        # Create data source
        datasource_name = f"pandas_datasource_{suite_name}"
        
        try:
            datasource = self.context.get_datasource(datasource_name)
        except:
            datasource = self.context.sources.add_pandas(datasource_name)
        
        # Add data asset
        asset_name = f"data_asset_{suite_name}"
        try:
            data_asset = datasource.get_asset(asset_name)
        except:
            data_asset = datasource.add_dataframe_asset(asset_name)
        
        # Create batch request
        batch_request = data_asset.build_batch_request(dataframe=data)
        
        # Create or get checkpoint
        if checkpoint_name is None:
            checkpoint_name = f"checkpoint_{suite_name}"
        
        try:
            checkpoint = self.context.get_checkpoint(checkpoint_name)
        except:
            checkpoint = self.context.add_checkpoint(
                name=checkpoint_name,
                validations=[
                    {
                        "batch_request": batch_request,
                        "expectation_suite_name": suite_name
                    }
                ]
            )
        
        # Run validation
        results = checkpoint.run()
        
        # Extract validation results
        validation_result = results.list_validation_results()[0]
        
        return {
            "success": validation_result.success,
            "statistics": validation_result.statistics,
            "results": validation_result.results,
            "evaluated_expectations": len(validation_result.results),
            "successful_expectations": validation_result.statistics["successful_expectations"],
            "failed_expectations": validation_result.statistics["unsuccessful_expectations"],
            "success_percentage": validation_result.statistics["success_percent"]
        }
    
    def generate_data_docs(self) -> str:
        """Generate and return path to data documentation."""
        self.context.build_data_docs()
        
        # Get the path to data docs
        data_docs_sites = self.context.get_docs_sites_urls()
        
        if data_docs_sites:
            return data_docs_sites[0]['site_url']
        else:
            return "Data docs generation failed"


def create_sample_schema() -> Dict[str, Any]:
    """Create a sample data schema for demonstration."""
    return {
        "columns": {
            "feature_1": {
                "type": "float64",
                "nullable": False,
                "min_value": 0.0,
                "max_value": 1.0,
                "feature_type": "numerical",
                "expected_mean_min": 0.4,
                "expected_mean_max": 0.6,
                "expected_std_min": 0.1,
                "expected_std_max": 0.3
            },
            "feature_2": {
                "type": "int64",
                "nullable": False,
                "min_value": 1,
                "max_value": 100,
                "feature_type": "numerical"
            },
            "feature_3": {
                "type": "object",
                "nullable": False,
                "allowed_values": ["A", "B", "C", "D"],
                "feature_type": "categorical"
            },
            "target": {
                "type": "int64",
                "nullable": False,
                "allowed_values": [0, 1],
                "task_type": "classification",
                "expected_classes": [0, 1],
                "min_class_ratio": 0.1
            },
            "timestamp": {
                "type": "datetime64[ns]",
                "nullable": False
            }
        },
        "target_column": "target",
        "timestamp_column": "timestamp",
        "max_data_age_days": 7,
        "check_duplicates": True
    }


if __name__ == "__main__":
    # Example usage
    validator = MLDataValidator()
    
    # Create sample data
    sample_data = pd.DataFrame({
        "feature_1": [0.5, 0.6, 0.4, 0.7, 0.3],
        "feature_2": [10, 20, 30, 40, 50],
        "feature_3": ["A", "B", "A", "C", "B"],
        "target": [1, 0, 1, 1, 0],
        "timestamp": pd.date_range("2024-01-01", periods=5, freq="D")
    })
    
    # Create expectation suite
    schema = create_sample_schema()
    suite = validator.create_ml_expectation_suite("ml_data_validation", schema)
    
    # Validate data
    results = validator.validate_data(sample_data, "ml_data_validation")
    
    print("Validation Results:")
    print(f"Success: {results['success']}")
    print(f"Success Rate: {results['success_percentage']:.1f}%")
    print(f"Successful Expectations: {results['successful_expectations']}")
    print(f"Failed Expectations: {results['failed_expectations']}")
    
    # Generate documentation
    docs_url = validator.generate_data_docs()
    print(f"Data docs available at: {docs_url}") 