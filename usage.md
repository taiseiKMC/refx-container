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

### Execution Flow
- `tezos-client refinement <src>`はまずソースコードから`<<`と`>>`で囲まれた注釈を除去し、型チェック`tezos-client typecheck`を実行します
- 型チェックに成功したら、`tezos-client refinement`は注釈から条件式を生成します
    - 生成された条件式は`.refx/out.smt2`か、`-l`オプションで指定したディレクトリで確認できます
- 最後に生成された条件式を `z3` で検証し、その出力をもとに検証器は`VERIFIED`か`UNVERIFIED`を出力します

### Annotation
注釈は次の6種類です
- `ContractAnnot`
    - プログラム全体の事前、事後条件、例外の値の条件及び環境変数を与えます
    - `code`の直前に書かなければなりません
- `LambdaAnnot`
    - `LAMBDA`命令で与える命令列を実行する際の事前、事後条件、例外の値の条件及びLAMBDA内で使える環境変数を与えます
    - `LAMBDA`命令の直前に書かなければなりません
- `Assert`
    - `Assert`を書いた地点までプログラムを実行した際に、与える条件を満たしているか確認します
    - 命令列中の間に書くことができます
- `Assume`
    - 書いた地点以降で与えた条件を仮定します
    - 命令列中の間に書くことができます
- `LoopInv`
    - ループ不変条件を指定します
    - **ループ以前に仮定された条件は、`LoopInv`に記述したこと以外は全てなくなります**
    - `LOOP`, `ITER`の直前に書かなければなりません
        - `MAP`, `LOOP_LEFT` are not yet supported
- `Measure`
    - list, set, map の仕様をある程度記述できるようにするための機能です
    - `ContractAnnot`の前に書いてください

### Syntax
```
ANNOTATION ::=
	| Assert RTYPE
	| LoopInv RTYPE
	| Assume RTYPE
	| LambdaAnnot RTYPE -> RTYPE & RTYPE
	| LambdaAnnot RTYPE -> RTYPE & RTYPE TVARS
	| ContractAnnot RTYPE -> RTYPE & RTYPE
	| ContractAnnot RTYPE -> RTYPE & RTYPE TVARS
	| Measure VAR : SORT -> SORT where [] = EXP | VAR :: VAR = EXP	
	| Measure VAR : SORT -> SORT where EmptySet = EXP | Add e s = EXP
	| Measure VAR : SORT -> SORT where EmptyMap = EXP | Bind k v m = EXP
RTYPE ::= { STACK | EXP } # この|、間違えられないか？
TVARS ::= (VAR : SORT, VAR : SORT, ...)
VAR ::= [a-z][a-z A-Z 0-9 _ ']*
STACK ::= 
	| PATTERN
	| PATTERN : STACK
EXP ::=
	| EXP OP EXP
	| UOP EXP
	| EXP EXP
	| NUMBER
	| STRING
	| BYTES
	| Key STRING
	| Key BYTES
	| Address STRING
	| Address BYTES
	| Signature STRING
	| Signature BYTES
	| Timestamp STRING
	| (EXP)
	| EXP.ACCESSER
	| if EXP then EXP else EXP
	| CONSTRUCTOR
	| EXP, EXP
	| []
	| EXP :: EXP
	| [EXP; EXP; ...]
	| match EXP with PATTERNS
OP ::= + | - | * | / | < | > | <= | >= | = | <> | && | || | mod | :: | ^
UOP ::= - | !
ACCESSER ::= first | second
PATTERNS ::= | PATTERN -> EXP
PATTERN ::=
	| CONSTRUCTOR VAR VAR ...
	| CONSTRUCTOR <SORT> VAR VAR ...
	| PATTERN, PATTERN
	| VAR
	| PATTERN :: PATTERN
	| []
	| [PATTERN; PATTERN; ...]
	| _
SORT ::=
	| int | unit | nat | mutez | timestamp | bool | string
	| bytes | key | address | signature | operation
	| pair SORT SORT | list SORT | (SORT)
	| contract SORT | option SORT | or SORT SORT | fun SORT SORT
	| map SORT SORT | set SORT SORT
```

SORTはほぼMichelsonのtypeと同じですが、key_hashはaddressに統合されている点、lambda が fun になっている点が異なります
(これ割とすぐに修正可能だしMichelsonのtypeと同じにしてしまった方が良いかも)

#### Constructors
EXPとしてコンストラクタを使う場合は型推論によってつける必要がないが、パターン内でコンストラクタを使う場合は、<ty>をつけないといけない場合があります

- `Nil` : list 'a
- `Cons` : 'a -> list 'a -> list 'a
- `Left` : 'a -> or 'a 'b
- `Right` : 'a -> or 'b 'a
- `Some` : 'a -> option 'a
- `None` : option 'a
- `True` : bool
- `False` : bool
- `Unit` : unit
- `Pack` <ty> : ty -> bytes
    - `PACK`, `UNPACK`命令に相当しますが、型情報が必要な都合上コンストラクタとして表現しています
- `Contract` <ty> : address -> contract ty
- `SetDelegate` : option key -> operation
- `TransferTokens` <ty> : ty -> mutez -> contract ty -> operation
- `CreateContract` <ty> : option address -> mutez -> ty -> address -> operation
    - `CreateContract ka tz stor addr`は、スタックが`ka : tz : stor : S`の状態で `CREATE_CONTRACT`を実行して`addr : op : S`の状態になったときのopを表します
    
- `Error` <ty> : ty -> string
    - FAILWITH例外を表します
- `Overflow` : string
    - mutezの乗算など、オーバーフローした場合に送出される例外を表します

#### Built-in Instructions
全部説明書くんかな...
- `not` : bool -> bool
- `get_str` : string -> int -> string
    - `get_str s i`で s の i 文字目を取得し、1文字のstringとして返します
- `sub_str` : string -> int -> int -> string
    - `sub_str s i l` で s の i 文字目から l 文字をとった部分文字列を返します
- `len_str` : string -> int
    - 文字列の長さを返します
- `concat_str` : string -> string -> string
    - 文字列を結合します `^`演算子と同じです
- `get_bytes` : bytes -> int -> bytes
- `sub_bytes` : bytes -> int -> int -> bytes
- `len_bytes` : bytes -> int
- `concat_bytes` : bytes -> bytes -> bytes
    - バイト列を結合します
- `first` : pair 'a 'b -> 'a
- `second` : pair 'a 'b -> 'b
- `find_opt` : 'a -> map 'a 'b -> option 'b
    - `find_opt k m`でm中からkで索引し、値`v`が存在すれば`Some v`、なければ`None`を返します
- `update` : 'a -> option 'b -> map 'a 'b -> map 'a 'b
    - `update k (Some v) m`とするとmのキーkに結びつく値をvで更新し、`update k None m`とすると削除します
- `empty_map` : map 'a 'b
- `mem` : 'a -> set 'a -> bool
- `add` : 'a -> set 'a -> set 'a
- `remove` : 'a -> set 'a -> set 'a
- `empty_set` : set 'a
- `source` : address
    - `SOURCE`命令で取得できる値です
- `sender` : address
    - `SENDER`命令で取得できる値です
- `self` : contract parameter_ty
    - `SELF`命令で取得できる値です
- `now` : timestamp
    - `NOW`命令で取得できる値です
- `balance` : mutez
    - `BALANCE`命令で取得できる値です
- `amount` : mutez
    - `AMOUNT`命令で取得できる値です
- `call` : fun 'a 'b -> 'a -> 'b -> bool
    - `call f a b`は、引数aにLAMBDAによって作られた関数fを適用すると停止し、返り値bとなるならばTrue、そうでなければFalseを表す関数です
- `hash` : key -> address
    - `HASH`命令に相当する関数です
- `blake2b` : bytes -> bytes
    - `BLAKE2B`命令に相当する関数です
- `sha256` : bytes -> bytes
    - `SHA256`命令に相当する関数です
- `sha512` : bytes -> bytes
    - `SHA512`命令に相当する関数です
- `sig` : key -> signature -> bytes -> bool
    - `CHECK_SIGNATURE`命令に相当する関数です

#### Language Spec
RTYPEのSTACKはどんなとかの話

#### Details
- `Key`, `Address`, `Signature`はコンストラクタではありません これは`key`, `address`, `signature` の値をパターンによって分解したいことがないと考えられるからです
- `Timestamp str`の str はRFC3339に沿った文字列である必要があります
-　現実装では `int` と `nat`, `mutez`, `timestamp`を型レベルで区別していません
- 結合順序はocaml準拠です

## Examples

### Boomerang.tz
```boomerang.tz
{
  parameter unit;
  storage unit;
  << ContractAnnot { arg | True } ->
      { ops, _ | match ops with [TransferTokens<unit> Unit tz (Contract addr)] -> addr = source && tz = balance | _ -> False } &
      { exc | False } >>
  code  { CDR ;
          NIL operation ;
          SOURCE ;
          CONTRACT unit ;
          ASSERT_SOME ;
          BALANCE ;
          UNIT ;
          TRANSFER_TOKENS ;
          CONS ;
          PAIR ;
        }
}
```
これは`source`へ`balance`を送るoperationを返すプログラムです。
ContractAnnotには、事前条件は何も仮定せず、事後条件にはその返り値が上で述べた仕様を満たすことを記述しています。
プログラム中にはスタックトップが`None`のときに例外を送出する`ASSERT_SOME`がありますが、ContractAnnotには例外の値の条件がFalse、つまり例外が起きないことを記述しています。実際`source`のaddressが指すアカウントは人間の操作するアカウントであるはずなので、`CONTRACT unit`は必ず成功するはずです。
そしてこのソースコードに対して`tezos-client refinement boomerang.tz`を実行すると`VERIFIED`と出力されるでしょう

### checksig.tz
```
parameter (pair signature string);
storage (pair address key);
<< ContractAnnot
    { arg | True } ->
    { ret | match ret.first, Pack arg.first.second with | [TransferTokens<string> _ _ (Contract addr) ], byt -> addr = arg.second.first && sig arg.second.second arg.first.first byt | _ -> False } &
    { err | err = Error Unit || err = Error 0 } >>
code  { DUP; DUP; DUP;
        DIP { CAR; UNPAIR; DIP { PACK } };
        CDDR;
        CHECK_SIGNATURE;
        ASSERT;

        UNPAIR;
        CDR;
        SWAP;
        CAR; CONTRACT string; IF_NONE { PUSH int 0; FAILWITH } {};
        SWAP;
        PUSH mutez 1;
        SWAP;
        TRANSFER_TOKENS;

        NIL operation;
        SWAP;
        CONS;
        DIP { CDR };
        PAIR };
```

このプログラムでは`ASSERT`, `PUSH int 0; FAILWITH`の二箇所からそれぞれ`Error Unit`, `Error 0`の例外が送出され得ます。ContractAnnotでは、この2つの例外が起こりうることを記述しています。
この例では例外が起こりうることを許容することで事後条件にはより強い主張ができています。上のプログラムでは引数のsignatureの検証、storage上のaddressの指すコントラクトの引数型チェックをしており、それぞれ失敗すると上記の例外が出るわけですが、このプログラムが正常終了した場合はどちらもうまくいっているはずであり、事後条件にはそのことが記述されています。

### sumseq.tz
```
{ parameter (list int);
  storage int;
  << Measure sumseq : (list int) -> int where Nil = 0 | Cons h t = (h + (sumseq t)) >>
  << ContractAnnot { arg | True } ->
      { ret | sumseq (first arg) = second ret }
      & { exc | False } (l:list int) >>
  code { CAR;
         << Assume { x | x = l } >>
         DIP { PUSH int 0 };
         << LoopInv { r:s | l = first arg && s + sumseq r = sumseq l } >>
         ITER { ADD };
         NIL operation;
         PAIR;
       }
}
```
この例は環境変数, Assume, LoopInv, Measureの紹介です。
このプログラムは、まず先頭で list int の要素を全て足した値を Measure によって定義しています。
次に Assume によってその時点での stack の値を環境変数`l`に結びつけています。この`l`は ContractAnnot の末尾で定義されたものです。
そして LoopInv によって ITER 中でのループ不変条件を与えます。`ITER { ADD }`は、list の先頭をスタックの先頭から2番目`s`に全て足す命令です。ループ不変条件`s + sumseq r = sumseq l`は、処理中のリスト`r`の総和に`s`を足すと、最初のリスト`l`の総和と等しくなるということが表現されています。
LoopInvを減るとそれまでの仮定が失われてしまうので、Assumeで書いた条件は忘れられています。なので`l = first arg`をループ不変条件に追加して、`l`の値の条件が忘れられないようにしています。