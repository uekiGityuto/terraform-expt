# terraform-expt

## 概要

ECS で Web アプリケーション（FastAPI）を稼働させるためのインフラ

## アプリケーション

ECS で稼働させるアプリケーションは[fast-api-expt](https://github.com/uekiGityuto/fast-api-expt)

## 開発

### VSCode Dev Container

[VSCode Dev Container](https://code.visualstudio.com/docs/remote/containers)を利用している。
Dev Container を使うことを強制はしないが、使わない場合は、必要なライブラリを自分でインストールすること。

### pre-commit フック

[pre-commit-terraform](https://github.com/antonbabenko/pre-commit-terraform#terraform_docs)を利用して、commit 時に 自動で lint をかけている。commit ができなかった場合は、pre-commit-terraform による lint エラーを疑うこと。

Git のログには詳細なログは出力されないので、ターミナルから以下のコマンドを実行して、lint エラーの原因を確認すること。

```sh
pre-commit run -a
```

# 事前準備

## GitHub リポジトリの設定

Environments に staging と production を作成する。
production は Deployment protection rules で、Required reviewers にチェックをいれる。

## AWS の準備

環境ごとに以下を実施する。

### Terraform Backend 用リソース作成

CloudFormation で作成する。

1. CloudFormation のコンソール画面でスタックの作成を開く
1. テンプレートに`terraform-backend.yaml`を指定する
1. スタックの名前を指定する（e.g. `stg-terraform-state`）
1. Environment パラメータに環境名（e.g. `stg`, `prod`）を入力する
1. タグを入力する（e.g. `{env: stg, service: terraform-expt}`）

なお、terraform-backend.yaml は[こちら](https://dev.classmethod.jp/articles/terraform-state-backend-cfn-service-catalog/)を参考にした。

### ドメインを取得して Route53 に登録

1. ドメインを取得する
1. ドメインを Route53 に登録
1. Amazon Route53 でホストゾーンを作成
1. ドメイン取得元のサイトでネームサーバを設定

なお、Route53 でドメインを取得した場合はドメインを Route53 に登録する作業は自動で実施されると思われる。
このリポジトリでは、お名前.com で登録したドメインを利用している。（[参考](https://dev.classmethod.jp/articles/route53-domain-onamae/)）

### OIDC で AWS 認証するための準備

GitHub Actions で OIDC を使用して AWS 認証するために、ID プロバイダや IAM ロールを作成する。
なお、シングルアカウントの場合は、環境ごとでなく一つ作成すれば良い。

CloudFormation で作成する。

1. CloudFormation のコンソール画面でスタックの作成を開く
1. テンプレートに`oidc-github.yaml`を指定する
1. スタックの名前を指定する（e.g. `stg-oidc-for-github-actions`）
1. タグを入力する（e.g. `{env: stg, service: terraform-expt}`）

なお、oidc-github.yaml は[こちら](https://zenn.dev/yuta28/articles/terraform-gha#fn-146a-1)を参考にした。
