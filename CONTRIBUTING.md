# 🤝 Contributing to Jenkins ML Pipeline

First off, thank you for considering contributing to Jenkins ML Pipeline! It's people like you that make this project an amazing tool for the MLOps community.

Following these guidelines helps to communicate that you respect the time of the developers managing and developing this open source project. In return, they should reciprocate that respect in addressing your issue, assessing changes, and helping you finalize your pull requests.

---

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Environment Setup](#development-environment-setup)
- [How to Contribute](#how-to-contribute)
- [Coding Standards](#coding-standards)
- [Testing Guidelines](#testing-guidelines)
- [Documentation](#documentation)
- [Community](#community)
- [Recognition](#recognition)

---

## 📜 Code of Conduct

This project and everyone participating in it is governed by our Code of Conduct. By participating, you are expected to uphold this code. Please report unacceptable behavior to [nguierochjunior@gmail.com](mailto:nguierochjunior@gmail.com).

### Our Pledge

We pledge to make participation in our project and our community a harassment-free experience for everyone, regardless of age, body size, disability, ethnicity, sex characteristics, gender identity and expression, level of experience, education, socio-economic status, nationality, personal appearance, race, religion, or sexual identity and orientation.

### Our Standards

Examples of behavior that contributes to creating a positive environment include:

- Using welcoming and inclusive language
- Being respectful of differing viewpoints and experiences
- Gracefully accepting constructive criticism
- Focusing on what is best for the community
- Showing empathy towards other community members

---

## 🚀 Getting Started

### What kinds of contributions we're looking for

Jenkins ML Pipeline is an open source project and we love to receive contributions from our community! There are many ways to contribute:

#### 🔧 **Infrastructure & DevOps**
- Terraform modules for new cloud providers
- Kubernetes manifests and Helm charts
- CI/CD pipeline improvements
- Security enhancements
- Performance optimizations

#### 🤖 **ML Components**
- New model types and frameworks
- Data validation frameworks
- Bias detection algorithms
- Drift monitoring tools
- Model registry integrations

#### 📊 **Observability**
- Custom Grafana dashboards
- Prometheus alerting rules
- OpenTelemetry instrumentation
- Log parsing and analysis
- Performance metrics

#### 📚 **Documentation**
- Tutorials and guides
- API documentation
- Architecture diagrams
- Use case examples
- Translation to other languages

#### 🧪 **Testing**
- Unit test coverage
- Integration tests
- Performance benchmarks
- Security tests
- End-to-end scenarios

#### 🐛 **Bug Reports & Features**
- Bug fixes
- Feature requests
- Performance improvements
- User experience enhancements

---

## 💻 Development Environment Setup

### Prerequisites

Ensure you have the following tools installed:

```bash
# Required tools
kubectl >= 1.25
helm >= 3.8
terraform >= 1.5
docker >= 20.10
python >= 3.9
node.js >= 16 (for documentation)

# Optional but recommended
kind >= 0.20 (for local development)
minikube >= 1.30 (alternative to kind)
k9s (for Kubernetes management)
```

### Quick Setup

1. **Fork and Clone the Repository**
   ```bash
   # Fork the repository on GitHub first
   git clone https://github.com/YOUR_USERNAME/jenkins-ml-pipeline.git
   cd jenkins-ml-pipeline
   
   # Add upstream remote
   git remote add upstream https://github.com/nguie2/jenkins-ml-pipeline.git
   ```

2. **Set Up Development Environment**
   ```bash
   # Run the development setup script
   ./scripts/dev-setup.sh
   
   # This will:
   # - Install required dependencies
   # - Set up pre-commit hooks
   # - Create local development cluster
   # - Install development tools
   ```

3. **Verify Installation**
   ```bash
   # Run the verification script
   ./scripts/verify-setup.sh
   
   # Check that all components are working
   kubectl get pods --all-namespaces
   ```

### Development Cluster Setup

For local development, we use kind (Kubernetes in Docker):

```bash
# Create development cluster
./scripts/dev-cluster.sh

# Deploy Jenkins ML Pipeline
./scripts/setup.sh --environment development --cluster-name dev-cluster

# Port forward services for local access
kubectl port-forward svc/jenkins 8080:8080 -n jenkins &
kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring &
```

### IDE Configuration

#### Visual Studio Code

Recommended extensions:
```json
{
  "recommendations": [
    "ms-python.python",
    "ms-python.black-formatter",
    "ms-python.pylint",
    "hashicorp.terraform",
    "ms-kubernetes-tools.vscode-kubernetes-tools",
    "redhat.vscode-yaml",
    "ms-vscode.docker"
  ]
}
```

#### IntelliJ IDEA / PyCharm

Required plugins:
- Python
- Docker
- Kubernetes
- Terraform and HCL
- YAML/Ansible Support

---

## 🔄 How to Contribute

### Contribution Workflow

1. **Find or Create an Issue**
   - Browse [existing issues](https://github.com/nguie2/jenkins-ml-pipeline/issues)
   - Create a new issue if your contribution doesn't have one
   - Comment on the issue to let others know you're working on it

2. **Create a Feature Branch**
   ```bash
   # Update your fork
   git checkout main
   git pull upstream main
   
   # Create a feature branch
   git checkout -b feature/your-feature-name
   ```

3. **Make Your Changes**
   - Follow our coding standards (see below)
   - Add tests for new functionality
   - Update documentation
   - Ensure all tests pass

4. **Commit Your Changes**
   ```bash
   # Stage your changes
   git add .
   
   # Commit with descriptive message
   git commit -m "feat: add bias detection for computer vision models
   
   - Implement Alibi Detect integration for CV models
   - Add new dashboard metrics for bias monitoring
   - Update documentation with CV bias detection guide
   
   Fixes #123"
   ```

5. **Push and Create Pull Request**
   ```bash
   # Push to your fork
   git push origin feature/your-feature-name
   
   # Create pull request on GitHub
   ```

### Commit Message Format

We follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

Types:
- `feat`: A new feature
- `fix`: A bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

Examples:
```bash
feat(monitoring): add GPU utilization metrics to Grafana dashboard
fix(terraform): resolve Jenkins service account permissions issue
docs(readme): update installation instructions for macOS
test(ml): add unit tests for bias detection module
```

### Pull Request Guidelines

#### Before Submitting

- [ ] All tests pass (`./scripts/run-tests.sh`)
- [ ] Code follows our style guidelines
- [ ] Documentation is updated
- [ ] Commit messages follow our format
- [ ] No merge conflicts with main branch

#### Pull Request Template

When creating a PR, use this template:

```markdown
## Description
Brief description of changes and motivation.

## Type of Change
- [ ] Bug fix (non-breaking change that fixes an issue)
- [ ] New feature (non-breaking change that adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update

## Testing
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing completed
- [ ] Performance impact assessed

## Screenshots (if applicable)
Add screenshots for UI changes.

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] Tests added/updated
- [ ] No breaking changes (or marked as such)
```

---

## 📐 Coding Standards

### Python

We use strict Python coding standards:

```bash
# Code formatting
black --line-length 100 src/ tests/

# Linting
pylint src/ tests/ --fail-under=8.0

# Type checking
mypy src/ --strict

# Import sorting
isort src/ tests/
```

#### Python Style Guide

- **Line length**: 100 characters maximum
- **Imports**: Use absolute imports, sorted with isort
- **Type hints**: Required for all public functions
- **Docstrings**: Google style for all modules, classes, and functions
- **Error handling**: Use specific exceptions, never bare except clauses

Example:
```python
"""Module for ML model bias detection.

This module provides utilities for detecting bias in machine learning models
using various statistical and fairness metrics.
"""

from typing import Dict, List, Optional, Tuple
import logging

import numpy as np
from alibi_detect import BiasDetector

logger = logging.getLogger(__name__)


class ModelBiasDetector:
    """Detects bias in ML model predictions.
    
    Attributes:
        model_name: Name of the model being monitored.
        threshold: Bias threshold for alerting.
    """
    
    def __init__(self, model_name: str, threshold: float = 0.05) -> None:
        """Initialize bias detector.
        
        Args:
            model_name: Name of the model to monitor.
            threshold: Bias threshold above which alerts are triggered.
            
        Raises:
            ValueError: If threshold is not between 0 and 1.
        """
        if not 0 <= threshold <= 1:
            raise ValueError("Threshold must be between 0 and 1")
            
        self.model_name = model_name
        self.threshold = threshold
        self._detector = BiasDetector()
    
    def detect_bias(
        self, 
        predictions: np.ndarray, 
        protected_attributes: np.ndarray
    ) -> Dict[str, float]:
        """Detect bias in model predictions.
        
        Args:
            predictions: Model predictions array.
            protected_attributes: Protected group attributes.
            
        Returns:
            Dictionary containing bias metrics.
            
        Raises:
            ValueError: If input arrays have mismatched shapes.
        """
        if predictions.shape[0] != protected_attributes.shape[0]:
            raise ValueError("Predictions and attributes must have same length")
            
        try:
            bias_score = self._detector.detect(predictions, protected_attributes)
            logger.info(f"Bias detection completed for {self.model_name}")
            return {"bias_score": bias_score, "threshold_exceeded": bias_score > self.threshold}
        except Exception as e:
            logger.error(f"Bias detection failed: {e}")
            raise
```

### Terraform

Follow HashiCorp's Terraform style conventions:

```hcl
# Variables at the top
variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  validation {
    condition     = length(var.cluster_name) > 0
    error_message = "Cluster name cannot be empty."
  }
}

# Local values for computed values
locals {
  common_labels = {
    app         = "jenkins-ml-pipeline"
    environment = var.environment
    managed-by  = "terraform"
  }
}

# Resources with clear naming
resource "kubernetes_deployment" "jenkins_controller" {
  metadata {
    name      = "jenkins-controller"
    namespace = var.namespace
    labels    = local.common_labels
  }
  
  spec {
    replicas = var.jenkins_replicas
    
    selector {
      match_labels = {
        app = "jenkins-controller"
      }
    }
    
    template {
      metadata {
        labels = merge(local.common_labels, {
          app = "jenkins-controller"
        })
      }
      
      spec {
        container {
          name  = "jenkins"
          image = "${var.jenkins_image}:${var.jenkins_tag}"
          
          resources {
            requests = {
              cpu    = var.jenkins_cpu_request
              memory = var.jenkins_memory_request
            }
            limits = {
              cpu    = var.jenkins_cpu_limit
              memory = var.jenkins_memory_limit
            }
          }
        }
      }
    }
  }
}
```

### YAML/Kubernetes

Use consistent YAML formatting:

```yaml
# Kubernetes manifests
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ml-model-server
  namespace: ml-models
  labels:
    app: jenkins-ml-pipeline
    component: ml-model
    version: v1.0.0
spec:
  replicas: 3
  selector:
    matchLabels:
      app: ml-model-server
  template:
    metadata:
      labels:
        app: ml-model-server
        version: v1.0.0
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/metrics"
    spec:
      serviceAccountName: ml-model-server
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
      containers:
      - name: ml-model
        image: ml-model:latest
        imagePullPolicy: Always
        ports:
        - containerPort: 8080
          name: http
          protocol: TCP
        env:
        - name: MODEL_NAME
          value: "fraud-detection"
        - name: LOG_LEVEL
          value: "INFO"
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
```

---

## 🧪 Testing Guidelines

### Test Structure

Our test structure follows the standard Python testing conventions:

```
tests/
├── unit/                    # Unit tests
│   ├── test_bias_detection.py
│   ├── test_drift_monitoring.py
│   └── test_model_registry.py
├── integration/             # Integration tests
│   ├── test_jenkins_pipeline.py
│   ├── test_monitoring_stack.py
│   └── test_security_scanning.py
├── performance/             # Performance tests
│   ├── test_model_inference.py
│   └── locustfile.py
├── security/                # Security tests
│   ├── test_rbac.py
│   └── test_network_policies.py
└── fixtures/                # Test fixtures
    ├── sample_data/
    └── test_configs/
```

### Writing Tests

#### Unit Tests

```python
"""Unit tests for bias detection module."""

import pytest
import numpy as np
from unittest.mock import Mock, patch

from src.ml_components.bias_detection import ModelBiasDetector


class TestModelBiasDetector:
    """Test suite for ModelBiasDetector class."""
    
    @pytest.fixture
    def detector(self):
        """Create bias detector instance for testing."""
        return ModelBiasDetector(model_name="test-model", threshold=0.05)
    
    @pytest.fixture
    def sample_data(self):
        """Generate sample test data."""
        predictions = np.random.rand(100)
        protected_attributes = np.random.randint(0, 2, 100)
        return predictions, protected_attributes
    
    def test_init_valid_threshold(self):
        """Test detector initialization with valid threshold."""
        detector = ModelBiasDetector("test", threshold=0.1)
        assert detector.threshold == 0.1
        assert detector.model_name == "test"
    
    def test_init_invalid_threshold_raises_error(self):
        """Test detector initialization with invalid threshold raises ValueError."""
        with pytest.raises(ValueError, match="Threshold must be between 0 and 1"):
            ModelBiasDetector("test", threshold=1.5)
    
    def test_detect_bias_success(self, detector, sample_data):
        """Test successful bias detection."""
        predictions, protected_attributes = sample_data
        
        with patch.object(detector._detector, 'detect', return_value=0.03):
            result = detector.detect_bias(predictions, protected_attributes)
            
        assert "bias_score" in result
        assert "threshold_exceeded" in result
        assert result["bias_score"] == 0.03
        assert result["threshold_exceeded"] is False
    
    def test_detect_bias_mismatched_shapes_raises_error(self, detector):
        """Test bias detection with mismatched input shapes raises ValueError."""
        predictions = np.random.rand(100)
        protected_attributes = np.random.randint(0, 2, 50)
        
        with pytest.raises(ValueError, match="Predictions and attributes must have same length"):
            detector.detect_bias(predictions, protected_attributes)
    
    @patch('src.ml_components.bias_detection.logger')
    def test_detect_bias_logs_completion(self, mock_logger, detector, sample_data):
        """Test that bias detection logs completion message."""
        predictions, protected_attributes = sample_data
        
        with patch.object(detector._detector, 'detect', return_value=0.03):
            detector.detect_bias(predictions, protected_attributes)
            
        mock_logger.info.assert_called_once_with("Bias detection completed for test-model")
```

#### Integration Tests

```python
"""Integration tests for Jenkins pipeline."""

import pytest
import requests
import subprocess
import time
from kubernetes import client, config


class TestJenkinsPipeline:
    """Integration tests for Jenkins ML pipeline."""
    
    @classmethod
    def setup_class(cls):
        """Set up test environment."""
        config.load_kube_config()
        cls.k8s_apps_v1 = client.AppsV1Api()
        cls.k8s_core_v1 = client.CoreV1Api()
        cls.jenkins_url = "http://jenkins.jenkins.svc.cluster.local:8080"
    
    def test_jenkins_is_running(self):
        """Test that Jenkins is running and accessible."""
        response = requests.get(f"{self.jenkins_url}/login", timeout=30)
        assert response.status_code == 200
        assert "Jenkins" in response.text
    
    def test_jenkins_plugins_installed(self):
        """Test that required Jenkins plugins are installed."""
        response = requests.get(
            f"{self.jenkins_url}/pluginManager/api/json?depth=1",
            auth=("admin", "admin123"),
            timeout=30
        )
        assert response.status_code == 200
        
        plugins = response.json()["plugins"]
        plugin_names = [plugin["shortName"] for plugin in plugins]
        
        required_plugins = [
            "kubernetes",
            "workflow-aggregator",
            "prometheus",
            "opentelemetry"
        ]
        
        for plugin in required_plugins:
            assert plugin in plugin_names, f"Required plugin {plugin} not installed"
    
    def test_ml_pipeline_execution(self):
        """Test end-to-end ML pipeline execution."""
        # Trigger pipeline build
        build_response = requests.post(
            f"{self.jenkins_url}/job/ml-pipeline/build",
            auth=("admin", "admin123"),
            timeout=30
        )
        assert build_response.status_code == 201
        
        # Wait for build to complete (max 10 minutes)
        for _ in range(60):
            time.sleep(10)
            status_response = requests.get(
                f"{self.jenkins_url}/job/ml-pipeline/lastBuild/api/json",
                auth=("admin", "admin123"),
                timeout=30
            )
            
            if status_response.status_code == 200:
                build_data = status_response.json()
                if not build_data.get("building", True):
                    assert build_data["result"] == "SUCCESS"
                    break
        else:
            pytest.fail("Pipeline build did not complete within 10 minutes")
```

### Running Tests

```bash
# Run all tests
./scripts/run-tests.sh

# Run specific test categories
pytest tests/unit/ -v
pytest tests/integration/ -v --timeout=300
pytest tests/performance/ -v

# Run tests with coverage
pytest tests/ --cov=src/ --cov-report=html --cov-report=term

# Run security tests
pytest tests/security/ -v

# Run tests in parallel
pytest tests/ -n auto
```

### Performance Testing

We use Locust for performance testing:

```python
"""Performance tests for ML model inference."""

from locust import HttpUser, task, between
import json
import random


class MLModelUser(HttpUser):
    """Simulate user load on ML model inference endpoint."""
    
    wait_time = between(1, 3)
    
    def on_start(self):
        """Set up test user."""
        self.model_endpoint = "/predict"
        self.health_endpoint = "/health"
    
    @task(10)
    def predict(self):
        """Test model prediction endpoint."""
        payload = {
            "features": [random.random() for _ in range(10)],
            "model_version": "latest"
        }
        
        with self.client.post(
            self.model_endpoint,
            json=payload,
            headers={"Content-Type": "application/json"},
            catch_response=True
        ) as response:
            if response.status_code == 200:
                result = response.json()
                if "prediction" in result:
                    response.success()
                else:
                    response.failure("No prediction in response")
            else:
                response.failure(f"HTTP {response.status_code}")
    
    @task(1)
    def health_check(self):
        """Test health endpoint."""
        with self.client.get(self.health_endpoint, catch_response=True) as response:
            if response.status_code == 200:
                response.success()
            else:
                response.failure(f"Health check failed: HTTP {response.status_code}")
```

---

## 📚 Documentation

### Documentation Standards

- **Clear and concise**: Write for your audience
- **Examples included**: Provide practical examples
- **Up to date**: Keep docs current with code changes
- **Accessible**: Use inclusive language and clear structure

### Documentation Types

#### API Documentation

Use docstrings for all public APIs:

```python
def train_model(
    data_path: str,
    model_config: Dict[str, Any],
    output_path: str,
    *,
    validation_split: float = 0.2,
    random_seed: Optional[int] = None
) -> ModelTrainingResults:
    """Train a machine learning model with the given configuration.
    
    This function performs end-to-end model training including data loading,
    preprocessing, training, and validation. It supports various model types
    and automatically handles hyperparameter optimization.
    
    Args:
        data_path: Path to the training data directory. Must contain
            'train.csv' and optionally 'test.csv'.
        model_config: Dictionary containing model configuration. Must include
            'model_type' key with values like 'xgboost', 'random_forest', etc.
        output_path: Directory where trained model artifacts will be saved.
        validation_split: Fraction of training data to use for validation.
            Must be between 0.0 and 1.0. Defaults to 0.2.
        random_seed: Random seed for reproducibility. If None, a random
            seed will be generated.
    
    Returns:
        ModelTrainingResults object containing:
            - trained_model: The trained model object
            - metrics: Dictionary of validation metrics
            - training_history: Training progress information
            - model_path: Path to saved model file
    
    Raises:
        FileNotFoundError: If data_path does not exist or required files are missing.
        ValueError: If model_config is invalid or validation_split is out of range.
        ModelTrainingError: If model training fails.
    
    Example:
        >>> config = {
        ...     'model_type': 'xgboost',
        ...     'hyperparameters': {
        ...         'max_depth': 6,
        ...         'learning_rate': 0.1
        ...     }
        ... }
        >>> results = train_model(
        ...     data_path='/data/training/',
        ...     model_config=config,
        ...     output_path='/models/',
        ...     validation_split=0.3
        ... )
        >>> print(f"Model accuracy: {results.metrics['accuracy']:.3f}")
        Model accuracy: 0.923
    
    Note:
        This function requires sufficient memory to load the entire dataset.
        For large datasets, consider using the streaming training API instead.
    """
```

#### Architecture Documentation

Use Architecture Decision Records (ADRs) for important decisions:

```markdown
# ADR-001: Choice of OpenTelemetry for Observability

## Status
Accepted

## Context
We need a comprehensive observability solution that provides:
- Distributed tracing across ML pipeline components
- Metrics collection from models and infrastructure
- Log correlation and analysis
- Vendor-neutral implementation

## Decision
We will use OpenTelemetry as our primary observability framework.

## Consequences

### Positive
- Vendor-neutral: No lock-in to specific monitoring vendors
- Comprehensive: Covers traces, metrics, and logs
- Industry standard: Wide adoption and community support
- Future-proof: CNCF graduated project with strong backing

### Negative
- Learning curve: Team needs to learn OpenTelemetry concepts
- Configuration complexity: More complex than single-vendor solutions
- Storage requirements: Need separate backends for traces/metrics/logs

## Implementation
- Deploy OpenTelemetry Collector in Kubernetes
- Instrument Python ML services with OpenTelemetry SDK
- Export traces to Jaeger, metrics to Prometheus, logs to Elasticsearch
- Create unified dashboards in Grafana
```

### Updating Documentation

When making changes:

1. **Update inline documentation** (docstrings, comments)
2. **Update relevant markdown files** in `/docs`
3. **Update README** if functionality changes
4. **Add examples** for new features
5. **Update architecture diagrams** if needed

---

## 🌟 Community

### Communication Channels

- **GitHub Issues**: Bug reports, feature requests, discussions
- **Email**: [nguierochjunior@gmail.com](mailto:nguierochjunior@gmail.com) for private matters
- **Twitter/X**: [@jean32529](https://x.com/jean32529) for announcements
- **LinkedIn**: [Nguie Angoue J](https://www.linkedin.com/in/nguie-angoue-j-2b2880254/) for professional networking

### Getting Help

1. **Check existing documentation** in `/docs`
2. **Search existing issues** on GitHub
3. **Ask questions** by creating a new issue with the "question" label
4. **Join discussions** on GitHub Discussions

### Reporting Bugs

When reporting bugs, please include:

```markdown
## Bug Description
Clear description of what happened vs. what you expected.

## Steps to Reproduce
1. Step one
2. Step two
3. Step three

## Environment
- OS: [e.g., Ubuntu 22.04]
- Kubernetes version: [e.g., 1.27.3]
- Jenkins ML Pipeline version: [e.g., 1.2.0]
- Browser (if applicable): [e.g., Chrome 118]

## Logs
```
Paste relevant logs here
```

## Screenshots
If applicable, add screenshots to help explain your problem.
```

### Suggesting Enhancements

Enhancement suggestions should include:

- **Clear use case**: Why is this needed?
- **Proposed solution**: How should it work?
- **Alternatives considered**: What other approaches did you consider?
- **Implementation impact**: What areas of the codebase would be affected?

---

## 🏆 Recognition

### Hall of Fame

Outstanding contributors will be recognized:

- **README acknowledgment**: Listed in project README
- **Release notes mention**: Highlighted in release announcements
- **Conference speaking opportunities**: Invitation to present their contributions
- **Swag and recognition**: Jenkins ML Pipeline branded items

### Contribution Levels

#### 🥉 **Bronze Contributor**
- 1+ merged pull request
- Active in discussions
- Helps other community members

#### 🥈 **Silver Contributor**
- 5+ merged pull requests
- Documentation contributions
- Bug reports with detailed reproduction steps

#### 🥇 **Gold Contributor**
- 15+ merged pull requests
- Major feature implementations
- Mentors new contributors
- Maintains project components

#### 💎 **Core Maintainer**
- Long-term project commitment
- Code review responsibilities
- Release management
- Community leadership

### Current Contributors

A huge thank you to all our contributors! This project wouldn't be possible without you.

<!-- This section will be automatically updated -->

---

## 📞 Questions?

Don't hesitate to reach out if you have questions:

- **General questions**: Create a GitHub issue with the "question" label
- **Security concerns**: Email [nguierochjunior@gmail.com](mailto:nguierochjunior@gmail.com)
- **Partnership opportunities**: LinkedIn message or email
- **Speaking engagements**: Email with "Speaking" in the subject line

---

## 📄 License

By contributing to Jenkins ML Pipeline, you agree that your contributions will be licensed under the [MIT License](LICENSE).

---

**Thank you for contributing to Jenkins ML Pipeline! Together, we're building the future of MLOps. 🚀** 