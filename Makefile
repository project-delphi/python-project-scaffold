SHELL := /bin/bash

.DEFAULT_GOAL:=help

.PHONY: help
help:  ## Prefer sandbox, validate, package-install and ml prefixed targets
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z0-9_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

.PHONY: list
list:
	@LC_ALL=C $(MAKE) -pRrq -f $(firstword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/(^|\n)# Files(\n|$$)/,/(^|\n)# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | grep -E -v -e '^[^[:alnum:]]' -e '^$@$$'

# Virtual environment

.PHONY: env-create
env-create:# Create virtual environment called .venv
	python3 -m venv .venv

.PHONY: env-activate
env-activate:# Activate virtual environment
	source ./.venv/bin/activate

.PHONY: env-deactivate
env-deactivate:# Deactivate virtual environment
	source deactivate

.PHONY: env-delete
env-delete:# Delete environment directory .venv
	rm -rf .venv

.PHONY: env-initiate
env-initiate: env-create env-activate# Create and activate virtual environment at .venv

# 3rd party package dependencies

.PHONY: install-upgrade-pip
install-upgrade-pip:# Upgrade pip version
	pip install --upgrade pip

.PHONY: install-dev
install-dev:# Install developer dependencies (formatting, linting)
	pip install -r requirements/requirements_dev.txt

.PHONY: install-test
install-test:# Install dependencies for testing
	pip install -r requirements/requirements_test.txt

.PHONY: install-run
install-run:# Install application only dependencies
	pip install -r requirements/requirements_run.txt

.PHONY: install
install: install-upgrade-pip install-dev install-test install-run# Upgrade pip and install developer, test & application dependencies

.PHONY: uninstall-dev
uninstall-dev:# Uninstall developer dependencies
	pip uninstall -r requirements/requirements_dev.txt

.PHONY: uninstall-test
uninstall-test:# Uninstall test dependencies
	pip uninstall -r requirements/requirements_test.txt

.PHONY: uninstall-run
uninstall-run:# Uninstall application only dependencies
	pip uninstall -r requirements/requirements_run.txt

.PHONY: uninstall
uninstall:# Uninstall all dependencies
	python -m pip uninstall -y -r <(pip freeze)

# Sandboxing: virtual environment & dependencies

.PHONY: sandbox-pre-commit-init
sandbox-pre-commit-init:## Create a new virtual environment and install all dependencies
	pre-commit install && pre-commit autoupdate

.PHONY: sandbox-new
sandbox-new: env-initiate install sandbox-pre-commit-init## Create a new virtual environment and install all dependencies

.PHONY: sandbox-new-run-only
sandbox-new-run-only: env-initial install-run## Create a new virtual environment and install application only dependencies

.PHONY: sandbox-destroy
sandbox-destroy: env-deactivate env-delete## Deactivate and delete virtual environment

.PHONY: sandbox
sandbox: sandbox-destroy sandbox-new## Destroy and make a new sandbox

# Linting

.PHONY: lint-ruff
lint-ruff:# Lint code using ruff for various styles and fix
	python -m ruff check --fix .

.PHONY: lint-mypy
lint-mypy:# Lint code using mypy type hints
	python -m mypy  -p src --check-untyped-defs

.PHONY: lint-typecheck
lint-typecheck: lint-mypy# Lint code for type hints


.PHONY: lint
lint: lint-ruff lint-typecheck## Lint code and docstrings

# Formatting

.PHONY: format-black
format-black:# Format code using black
	python -m black .

.PHONY: format
format: format-black## Format code

# Testing

.PHONY: pytest
pytest:# Run tests using pytest
	python -m pytest -vv src

.PHONY: coverage
coverage:# Test coverage analysis
	coverage run -m pytest

.PHONY: tests
tests: coverage## Run tests

# Running application code

.PHONY: serve
serve:# Serve app using microservices

.PHONY: app
app:# Run application in app.py
	python -m app.py

.PHONY: run
run: app# Run applcation

# Current repo's package install

.PHONY: package-install
package-install:## Install edtiable src package
	python -m pip install -e .

# Cleaning code generated artifacts

.PHONY: clean-build
clean-build:# Remove binary build files
	@rm -fr build/
	@rm -fr dist/
	@rm -fr *.egg-info

.PHONY: clean-pyc
clean-pyc:# Remove pyc files
	@find . -name '*.pyc' -exec rm -f {} +
	@find . -name '*.pyo' -exec rm -f {} +
	@find . -name '*~' -exec rm -f {} +

.PHONY: clean-cache
clean-cache:# Remove cached files
	@find . -type d -name '.pytype' -exec rm -rf {} +
	@find . -type d -name '.mypy_cache' -exec rm -rf {} +
	@find . -type d -name '__pycache__' -exec rm -rf {} +
	@find . -type d -name '*pytest_cache*' -exec rm -rf {} +
	@find . -type f -name "*.py[co]" -exec rm -rf {} +
	@find . -type f -name ".coverage.*" -exec rm -rf {} +
	@find . -type d -name '*.ipynb_checkpoints' -exec rm -r {} +

.PHONY: clean
clean: clean-build clean-pyc clean-cache# Remove unnecessary artifacts

.PHONY: polish
polish: format lint## Validate code with quality checks

.PHONY: validate
validate: clean install format lint tests## Validate code with quality checks

# pre-commit format & linting and testing

.PHONY: pre-commit-run
pre-commit-run:## Run updated pre-commit formatting and linting hooks on all files
	pre-commit run --all-files

.PHONY: pre-commit-run-validate
pre-commit-run-validate: clean pre-commit-run tests## Run updated pre-commit formatting and linting hooks on all files

# setup

.PHONY: on-create-command-setup
setup-on-create-command: sandbox-new ## first setup of dev environment

.PHONY: setup
setup: sandbox clean pre-commit-run tests # remake of environment along with tests

# Machine learning development cycle

.PHONY: ml-data-download
ml-data-download:# Download data
	python -m src/ml/data_download.py

.PHONY: ml-data-preprocess
ml-data-preprocess:# Preprocess data
	python -m src/ml/data_preprocess.py

.PHONY: ml-data-encode
ml-data-encode:# Encode data
	python -m src/ml/data_encode.py

.PHONY: ml-data-split
ml-data-split:# Split data
	python -m src/ml/data_split.py

.PHONY: ml-dev-train-parameters
ml-dev-train-parameters:# Develop model by training parameters
	python -m src/ml/dev_train_parameters.py

.PHONY: ml-dev-tune-hyperparameters
 ml-dev-tune-hyperparameters:# Develop model by tuning hyperparaemters
	python -m src/ml/dev_tune_hyperparameters.py

.PHONY: ml-model-test-performance
ml-model-test-performance:# Unbiased model performance estimate
	python -m src/ml/model_test_performance.py

.PHONY: ml-model-upload
ml-model-upload:# Upload model to cloud
	python -m src/ml/model_upload.py

.PHONY: ml-model-serve-api
ml-model-serve-api:# Serve model using microservices architecture
	python -m src/ml/model_serve_api.py

.PHONY: ml-model-learn
ml-model-learn: ml-data-split ml-dev-train-parameters \ ## Train, tune and estimate expected model performance
	 ml-dev-tune-hyperparameters ml-model-test-performance

.PHONY: ml
ml: install ml-data-download ml-data-preprocess \ ## Build ml model starting from sandbox
	ml-data-split ml-dev-train-parameters \
	ml-dev-tune-hyperparameters ml-model-test-performance

# build and deploy

build:
	docker build -t $(AWS_ECR_REPO):latest .

push:
	echo $(AWS_ECR_LOGIN_PASSWORD) | docker login --username AWS --password-stdin $(AWS_ECR_REPO)
	docker push $(AWS_ECR_REPO):latest

deploy:
	aws apprunner create-service --service-name $(SERVICE_NAME) --source-configuration '{"AuthenticationConfiguration": {"AccessRoleArn": "$(AWS_ACCESS_ROLE_ARN)"}, "CodeRepository": {"RepositoryUrl": "$(GITHUB_REPO_URL)", "SourceCodeVersion": {"Type": "BRANCH", "Value": "$(GITHUB_BRANCH)", "AuthenticationConfiguration": {"ConnectionArn": "$(GITHUB_CONNECTION_ARN)"}}}'

# Add these as GitHub secrets and include them as environment variables in your CI/CD YAML
# AWS_ECR_LOGIN_PASSWORD: ${{ secrets.AWS_ECR_LOGIN_PASSWORD }}
# AWS_ECR_REPO: ${{ secrets.AWS_ECR_REPO }}
# SERVICE_NAME: ${{ secrets.SERVICE_NAME }}
# AWS_ACCESS_ROLE_ARN: ${{ secrets.AWS_ACCESS_ROLE_ARN }}
# GITHUB_REPO_URL: ${{ secrets.GITHUB_REPO_URL }}
# GITHUB_BRANCH: ${{ secrets.GITHUB_BRANCH }}
# GITHUB_CONNECTION_ARN: ${{ secrets.GITHUB_CONNECTION_ARN }}
