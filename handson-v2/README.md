# terraform-expt

## 事前準備

環境ごとに以下を実施する。

### Terraform Backend用リソース作成
CloudFormationで作成する。
1. CloudFormationのコンソール画面でスタックの作成を開く
1. テンプレートに`terraform-backend.yaml`を指定する
1. スタックの名前を指定する（e.g. `stg-terraform-state-backend`）
1. Environmentパラメータに環境名（e.g. `stg`, `prod`）を入力する
1. タグにenvを入力する（e.g. `{env: stg}`）

なお、terraform-backend.yamlは[こちら](https://dev.classmethod.jp/articles/terraform-state-backend-cfn-service-catalog/)を参考にした。

### ドメインを取得してRoute53に登録
1. ドメインを取得する
1. ドメインをRoute53に登録
  1. Amazon Route53でホストゾーンを作成
  1. ドメイン取得元のサイトでネームサーバを設定

なお、Route53でドメインを取得した場合はドメインをRoute53に登録する作業は自動で実施されると思われる。
このリポジトリでは、お名前.comで登録したドメインを利用している。（[参考](https://dev.classmethod.jp/articles/route53-domain-onamae/)）

## 補足
このリポジトリでは名前に環境名をつけているが、環境ごとにアカウントを分けている場合（マルチアカウント）の場合は不要。
