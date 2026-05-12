# Server-k3s

## Overview
홈서버에서 **K3s**를 이용한 환경 구축을 위해 필요한 파일 모음입니다.

## Structure
각 **Namespace** 안에 서비스들은 동일한 구조를 가집니다.
- `values.yaml` : **helm**을 이용한 배포에 사용되는 `values`를 모아놓은 `yaml` 파일입니다.
- `secret-sample.yaml` : 각 서비스를 위해 생성되는 **Secret**의 템플릿입니다. 
- `.env-sample` : `secret-sample.yaml`을 이용해 **Secret**을 생성할 때 사용하는 환경 변수 파일 템플릿입니다.

### [apps](/apps/README.md) 
편의 또는 기능성 웹 서비스를 배포하는 **Namespace** 입니다.

### [core-infra](/core-infra/README.md)
**K3s** 환경을 구축할 때 필요한 Ingress, Service 관련 서비스를 배포하는 **Namespace** 입니다.

### [database](/database/README.md)
데이터베이스를 배포하는 **Namespace** 입니다.

### [monitoring](/monitoring/README.md)
**K3s** 환경을 모니터링하거나 다른 웹 서비스를 모니터링하는데 쓰이는 서비스를 배포하는 **Namespace** 입니다.