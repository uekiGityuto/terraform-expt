# terraform-expt

## 概要

ECS で Web アプリケーション（FastAPI）を稼働させるためのインフラ。  
構成図は([こちら](https://drive.google.com/file/d/1e48v-ZHxnmmEbQOaunSUl6-sVhOwAvsD/view?usp=sharing))

## アプリケーション

ECS で稼働させるアプリケーションは[こちら](https://github.com/uekiGityuto/fast-api-expt)

## 開発

### VSCode Dev Container

[VSCode Dev Container](https://code.visualstudio.com/docs/remote/containers)を利用している。  
Dev Container を使うことを強制はしないが、使わない場合は、必要なライブラリを自分でインストールすること。

### pre-commit フック

[pre-commit-terraform](https://github.com/antonbabenko/pre-commit-terraform#terraform_docs)を利用して、commit 前に特定の処理を実施している。

pre-commit-terraform で実施する処理は大きく二種類ある。

- 自動で修正/作成する処理
  - この場合は修正/作成されたファイルがステージングされていない状態になるので、確認して問題なければ、`git add`して`git commit`する。
- 静的解析（lint）
  - commit がエラーになるが、Git のログからは lint エラーの原因は確認できない。そのため、ターミナルから以下のコマンドを実行して、原因を確認し、対応する。

```sh
pre-commit run -a
```

### 機密情報

機密情報は実行時に値を渡している。
GitHub Actions で実行するときは Secrets に登録するが、ローカルで実行するときは、`*.auto.tfvars`を作成しておけば、自動で実行時に値を渡してくれる。

例えば、各環境のディレクトリに`credential.auto.tfvars`を作成し、`variables.tf`で定義している変数の値を登録する。

## デプロイ

GitHub Actions の`Terraform CD`を実行する。実行時にデプロイする環境を選択すること。

# 事前準備

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

## GitHub リポジトリの設定

Environments に stg と prod を作成する。

### Environment variables

Environment variables に`ROLE_TO_ASSUME`を作成し、[OIDC で AWS 認証するための準備]で作成した IAM Role の ARN を設定する。（e.g. `arn:aws:iam::428485887053:role/terraform-expt-github-actions-exec`）

### Environment secrets

Environment secrets に実行時に渡す値を登録する。
登録する Key は GithubActions の yaml ファイルを確認する。

## 補足

SSM パラメータストアは手動で作成しようと思ったが、Terraform で作成することにした。  
理由は、RDS 作成時にマスターパスワードを入力する必要があるが、パラメータストアから値を取得して入力することが難しかったから。  
（ECS はパラメーターストアの ARN を渡せば値を取得してくれるが、RDS にはそのような機能はなかった。）  
そのため、RDS のマスターパスワードはパラメータストアに手動で保存するのではなく、実行時に直接渡すことにした。  
ECS の環境変数に機密情報を渡す際は、パラメータストアかシークレットマネジャーを使う必要があるので、直接渡したパスワードを Terraform でパラメーターストアに登録することにした。  
