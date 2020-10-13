# Helmholtz

Helmholtz is a static verification tool for Michelson, a smart contract language used in Tezos blockchain protocol.

## Install
tacas用
There are two files below in the given zip.
- dockerのdebパッケージ
- コンテナのimgファイル

```あとでちゃんとコマンドを書き下す
% unzip helmholtz.zip                 # Extract the zip
% dpkg -i docker.deb                  # Install docker
% docker load --input helmholtz.img   # Load the container
```

## Execute
- `% docker run -it helmholtz bash`
とすると、Helmholtzが実行可能な環境が立ち上がりbashが起動します
    - ローカルにあるファイルをコンテナ内で利用するために、通常は `docker run -it -v <path>:/home/opam/tezos helmholtz bash` とするでしょう
    - コンテナ内では tezos の sandbox 環境が立ち上がっています
- `% tezos-client refinement <src>` で、注釈付きのプログラム(ファイル or 文字列)を与えると、注釈中の条件を検証して出力します
- その他 tezos-client のサブコマンドは全て利用できます [Ref : Tezos Whitedoc](https://tezos.gitlab.io/api/cli-commands.html?highlight=tezos%20client)
    - tezosのバージョンは `005_PsBabyM1 Babylon` です

##### 多分書かない情報
- `% docker run -it helmholtz <command>`とすると、sandboxed-node を立ち上げる処理をしたのち command を実行します
    - 別にbashでなくても任意のコマンドで良いので、直接`tezos-client refinement`を叩いても良いです(実行後直ぐにコンテナが終了します)
```
% docker run -it helmholtz tezos-client refinement '{ parameter (list int);
  storage (list int);
  << ContractAnnot ...'
```

## Spec
とりあえず思いついたことを書いてます

- ツールに投げるソースコードは言語 [Michelson](https://tezos.gitlab.io/whitedoc/michelson.html) で記述されたプログラムに、`<<`と`>>`で囲まれた注釈を付与したコードである必要があります
- `tezos-client refinement`はまずプログラムから`<<`と`>>`で囲まれた注釈を除去し、型チェック`tezos-client typecheck`を実行します
- 型チェックに成功したら、除去