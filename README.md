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
- 成果物 (EdgeOS に `xz` が無いため gzip):
  - `alloy-<tag>-linux-mips64-softfloat.gz` と `.gz.sha256`
  - 固定名 `alloy-linux-mips64-softfloat.gz` と `.gz.sha256` (上記の複製。EdgeRouter の systemd timer から固定 URL で取得するため)
  - upstream の `LICENSE`

## EdgeRouter での自動更新 (systemd timer)

`systemd/` の 3 ファイルで、毎月 1 日 03:00 (ローカル時刻、最大 30 分のランダム遅延) に最新の Release を取得して差し替えます。

- `alloy-update.sh`: 取得、sha256 検証、展開、差し替え、起動確認を行うスクリプト
- `alloy-update.service`: スクリプトを実行する oneshot の unit
- `alloy-update.timer`: 月次で service を起動する timer

```sh
cd /config/user-data/grafana-alloy
# 3 ファイルをこのディレクトリに置く
chmod +x alloy-update.sh
sudo systemctl link /config/user-data/grafana-alloy/alloy-update.service
sudo systemctl enable --now /config/user-data/grafana-alloy/alloy-update.timer
```

確認方法:

```sh
systemctl list-timers alloy-update.timer      # 次回実行時刻
systemctl status alloy-update.service         # 直近の結果 (成功 / failed)
systemctl show alloy-update.service -p Result,ExecMainStatus   # Result=success, ExecMainStatus=0 なら成功
sudo systemctl start alloy-update.service     # 手動実行 (結果は status で確認)
```

EdgeOS は、フラッシュの消耗とメモリの圧迫を避けるため journal を永続化しません。`journalctl` ではログを確認できないので、成否は `systemctl status` の `Active:` と終了コード (`status=0/SUCCESS`) で判定してください。

- `latest` は「最後に作成された (prerelease でない) Release」です。古いタグを `workflow_dispatch` で作り直すと、
  `latest` がそのタグに切り替わります。古いタグの再ビルドは避けてください。
- 作業ファイルはすべて `/config/user-data/grafana-alloy/.tmp/` に置き (`alloy` と同一ファイルシステムなので最後の `mv` はリネームです)、実行の開始時と終了時に削除します。
- 差し替えの前に `.tmp/alloy.new --version` を実行し (pre-flight)、失敗したらサービスを停止せずに終了します。
- 起動後は約 10 秒待ち、`ActiveState=active` かつ MainPID が起動直後から変わっていないことを確認します。満たさなければエラー終了し、unit は `failed` になります。

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
- CI では qemu-user (`qemu-mips64-static`) で `alloy --version` を実行するスモークテストを行います (非ゲート、`continue-on-error`)。
- ライセンス: upstream は Apache-2.0。LICENSE を成果物に同梱します。
- このリポジトリ自身 (scripts / workflow / overlay) のライセンスは、upstream に合わせて Apache-2.0 です (`LICENSE`)。
  `LICENSE` は標準の Apache-2.0 全文で、著作権者の表記 (`Copyright [yyyy] [name of copyright owner]`) は附録のひな形のままです。
