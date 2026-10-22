# alloy-edgerouter-slim

EdgeRouter (Cavium / linux/mips64 big-endian, softfloat) 向けに、必要な 8 コンポーネントだけに絞った Grafana Alloy をビルドする非公式リポジトリ。
Grafana Labs とは無関係で、サポートもありません。

## 含まれるコンポーネント

`local.file_match` / `loki.source.file` / `loki.write` / `prometheus.exporter.dnsmasq` / `prometheus.exporter.unix` / `discovery.relabel` / `prometheus.scrape` / `prometheus.remote_write`

config コンバータと static モードはスタブに差し替えています (`go build -overlay`。upstream のファイルは変更しません)。

## upstream への追従

- GitHub Actions が毎日 (`schedule`) 動き、`grafana/alloy` の安定タグ (`vX.Y.Z`, rc 除く, v1.21.0 以上) のうち、
  upstream 側で Release が公開済み (draft / prerelease でない) の最新タグを選びます。
- このリポジトリに同名の Release があればスキップします。
- `workflow_dispatch` でタグを指定可能。`force` で既存 Release の作り直し (削除して再作成)。
- 成果物: `alloy-<tag>-linux-mips64-softfloat.xz` / `.sha256` / upstream の `LICENSE`。

## ローカルでのビルド

```sh
git clone --depth 1 --branch v1.21.1 https://github.com/grafana/alloy /tmp/alloy
scripts/build.sh /tmp/alloy v1.21.1 ./alloy      # コールドビルドで約 7-10 分
```

`make alloy` は使わず `collector/` で直接 `go build` します (`CGO_ENABLED=0 GOOS=linux GOARCH=mips64 GOMIPS64=softfloat`, `-mod=readonly`)。
`.git` の無いツリーでは Revision は環境変数 `REVISION` (無ければ `unknown`) になります。
`scripts/gen-overlay.sh <tree> <out>` は overlay だけを生成します。all.go が 8 import にならない場合は失敗します。

## 注意

- 60 日間リポジトリに活動が無いと、Public リポジトリの `schedule` は自動無効化されます。
  その場合は Actions タブで該当 workflow を開き "Enable workflow" を押して再有効化してください。
  (Release 作成が「活動」として数えられるかは未検証)
- 未検証: qemu-user での実行 (smoke test は非ゲート、`continue-on-error`) / ランナー上の所要時間とディスク使用量 / 実機での動作 (実機確認は人が行う)。
- ライセンス: upstream は Apache-2.0。LICENSE を成果物に同梱しますが、依存ライブラリの通知義務は未確認です。
- このリポジトリ自身 (scripts / workflow / overlay) のライセンスは、upstream に合わせて Apache-2.0 です (`LICENSE`)。
  `LICENSE` は標準の Apache-2.0 全文で、著作権者の表記 (`Copyright [yyyy] [name of copyright owner]`) は附録のひな形のままです。
