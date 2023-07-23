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

### 機密情報

SSM パラメータストアは手動で作成しようと思ったが、Terraform で作成することにした。  
理由は、RDS 作成時にマスターパスワードを入力する必要があるが、パラメータストアから値を取得して入力することが難しかったから。  
（ECS はパラメーターストアの ARN を渡せば値を取得してくれるが、RDS にはそのような機能はなかった。）  
そのため、RDS のマスターパスワードはパラメータストアに手動で保存するのではなく、実行時に直接渡すことにした。  
ECS の環境変数に機密情報を渡す際は、パラメータストアかシークレットマネジャーを使う必要があるので、直接渡したパスワードを Terraform でパラメーターストアに登録することにした。

### Image Tag

アプリケーションとインフラを別々のリポジトリで管理し、それぞれ別々にデプロイする想定で作成している。  
ただ、ECS のタスク定義のみアプリケーション側とインフラ側の両方から更新されてしまう。  
インフラ側でタスク定義を作成するので、インフラ側から更新されるのは当然だが、
タスク定義には利用する Image と Tag が記載されるので、アプリケーションデプロイ時に新しいタグに更新されてしまう。

Terraform で管理しているタスク定義と実際のタスク定義が異なる状態になり、以下の 2 つの問題が生じる。

1. Terraform 側でタスク定義を変更していないのに、plan や apply で差分が生じる
1. Terraform 側でタスク定義を変更したときに、最新の Tag がわからない

前者は aws_ecs_service の task_definition で指定するタスク定義を Terraform で作成したタスク定義ではなく、最新のタスク定義を取得して参照させることである程度回避できる（[参考](https://dev.classmethod.jp/articles/terraform_ecs_codepipeline_rollingupdate_taskdef/)）

しかし、後者が難しい。色々な方法があるが全てにメリデメがあり、ベストプラクティスがない。  
いくつかの方法とそれぞれのメリデメを記載する。

1. 常に最新の Tag（デプロイされている Image の Tag）を取得する
   - メリット: 正しいタグを指定できるので、デプロイが失敗しない
   - デメリット: ECS 以外（例えば RDS など）を更新したいときでも、Tag が更新されていれば、ECS も更新されてしまう。（実際には Task 内容の変更はないが、稼働中 Task の停止と起動が走ってしまう）
     - 先ほど記述した aws_ecs_service の task_definition で最新のタスク定義を取得するようにしていても、タスク定義（aws_ecs_task_definition）自体を更新してしまうので、差分が生じてしまう
1. Tag に latest をつける
   - メリット: Terraform で管理しているタスク定義と実際のタスク定義が一致する
   - デメリット: 明確なバージョニングが行えないので、ロールバックなどが難しい。また、同じタイミングで複数ブランチから push された場合にどちらが latest になるか制御できない。
1. Terraform 側では Tag をつけない
   - メリット: Terraform でタスク定義以外を更新したいときに、無駄にタスク定義の更新が走ることがない
   - デメリット: Terraform でタスク定義を更新したときに、正しく Tag を指定できていないので、デプロイに失敗する（Tag なしの Image があればそれを使ってしまう？）
     - その場合、手動でタスク定義を修正したり、アプリケーション側の CD を実行したりして、正しいタスク定義を指定し直す
1. Terraform でタスク定義を更新するときに、正しい Tag をハードコードする
   - メリット: タスク定義以外の更新で無駄にタスク定義の更新が走ることがなく、タスク定義を更新するときも正しくデプロイできる
   - デメリット: ヒューマンエラーが起きる

他にも、ECS のみアプリケーションコードのリポジトリで管理するとか、ArgoCD などのデプロイツールを使うとか、方法はいくつかある。  
個人的には、インフラを頻繁に変更することがないのであれば、1 番最初の「常に最新の Tag を取得する」方法が良さそうに思う。  
その場合は、ビルド時に SSM パラメーターストアに Tag をセットして、plan や apply を実行するときに、取得して渡してあげる形が良いと思う。
