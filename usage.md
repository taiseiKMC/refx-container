# Abstract
> [name=hsaito] ここで推敲します 
> [name=ksuenaga] 見ました．少し直しました．

Helmholtz is a static verification tool for Michelson---a smart contract language used in Tezos blockchain protocol. This tool takes a Michelson program annotated with a user-defined specification written in the form of a refinement type as input; it then typechecks the program against the specification based on our refinement type system, discharging the generated verification conditions with an SMT solver Z3.
Helmholtz is implemented as a subcommand of `tezos-client`, which is the client of Tezos blockchain.

This artifact is a docker container that provides an environment in which Helmholtz can be run.  The artifact also includes sample Michelson programs so that one can quickly try Helmholtz and confirm that the results in the accompanying paper is reproducible.

# Licence
> [name=hsaito] tezosはMITライセンス 同じで良い？
> [name=ksuenaga] 良いと思います．

Copyright (c) 2020 Igarashi Lab.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. 

> Readme.txtここから
# Helmholtz

Helmholtz is a static verification tool for [Michelson](https://tezos.gitlab.io/whitedoc/michelson.html), a smart contract language used in [Tezos](https://tezos.gitlab.io/) blockchain protocol.  It verifies that a Michelson program satisfies a user-written formal specification.


## Quickstart
To verify `src.tz` in <path-in-the-host> directory, sequentially execute the following commands in the host.
```
% unzip helmholtz.zip
% tar zxvf helmholtz/docker-19.03.9.tgz
% export PATH="$PATH:/home/$USER/docker"
% sudo dockerd &
% sudo docker load --input helmholtz/helmholtz.img
% sudo docker run -it helmholtz -v <path-in-the-host>:/home/opam/ReFX/mount tezos-client refinement mount/src.tz
```


## To reproduce the experimental result in the paper (for TACAS 2021 AEC)

The following two files are in the submitted zip file.
- .tgz package to install docker.
- .img file of the image of a Docker container of the artifact.

To install the artifact on the VM, execute the following commands:

```
% unzip helmholtz.zip                               # Extract the zip
% tar zxvf helmholtz/docker-19.03.9.tgz
% export PATH="$PATH:/home/$USER/docker"
% sudo dockerd &                                    # Run docker daemon
% sudo docker load --input helmholtz/helmholtz.img  # Load the container
```

And the following commands reproduce Table 1 in the paper.
```
% sudo docker run -it helmholtz ./run_tacas2021_contracts.sh
```
| contract name          | #instr | time(ms) |
|:-----------------------|-------:|---------:|
| boomerang.tz           |     17 |       35 |
| checksig.tz            |     38 |       65 |
| checksig_unverified.tz |     36 |       62 |
| deposit.tz             |     24 |       54 |
| manager.tz             |     29 |       60 |
| reservoir.tz           |     45 |       87 |
| triangular_num.tz      |     16 |       35 |
| vote.tz                |     24 |       62 |
| vote_for_delegate.tz   |     87 |      143 |
| xcat.tz                |     64 |      188 |

The contracts we used in the experiments are placed in `~/ReFX/test_contracts/tacas2021`. You can verify each contract by running `sudo docker run -it helmholtz tezos-client refinement test_contracts/tacas2021/<contract name>`.


### Detailed explanation of each command

> [name=ksuenaga] これは how to reproduce のセクションの末尾につけましょう．

- `sudo docker run -it helmholtz <command>` will run `<command>` such as `bash` running in an environment that can execute Helmholtz.
    - To share a directory with the host, run `docker run -it -v <path-in-the-host>:/home/opam/ReFX/mount helmholtz <command>`
    - Tezos should be running in a sandbox inside the container.
- To verify an annotated Michelson program `src.tz`, run `tezos-client refinement src.tz`.  You can write a program dirctly as a string instead of the file name `src.tz`.
    - Annotations are to give a formal specification (i.e., an intended behavior) and hints (e.g., a loop invariant) to a Michelson program.  See below for a detail.
- You can execute any subcommand of `tezos-client` (cf., [Tezos Whitedoc](https://tezos.gitlab.io/api/cli-commands.html?highlight=tezos%20client))
    - The version of the tezos running in the container is `005_PsBabyM1 Babylon`.

<!--
##### 多分書かない情報
- `% docker run -it helmholtz <command>`とすると、sandboxed-node を立ち上げる処理をしたのち command を実行します
    - 別にbashでなくても任意のコマンドで良いので、直接`tezos-client refinement`を叩いても良いです(実行後直ぐにコンテナが終了します)
```
% docker run -it helmholtz tezos-client refinement '{ parameter (list int);
  storage (list int);
  << ContractAnnot ...'
```
-->



## Example: Boomerang
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
The above code, which is the contents of `boomerang.tz` in the container, is a Michelson program that transfers money amout `balance` to an account `source`.  The program comes with an annotation surrounded by `<<` and `>>`.  
This annotation, which is labeled by a constructor `ContractAnnot`, states the following two properties.
+ The value `(ops, _)` stacked in the end of this program satisfies `ops = [TransferTokens Unit balance addr]`.
Second, no exceptions are raised from the instructions in this program. There is an `ASSERT_SOME` instruction in the program that sends out an exception when the stack top is `None`, but since the account pointed to by  `source` should be a human-operated account, the `CONTRACT unit` should always return `Some`, so it can't be an exception. The section `{ exc | False }` ContractAnnot contains states that the condition on the value of the exception is False, meaning that the exception does not occur. Then, if you run `tezos-client refinement boomerang.tz`, you will get `VERIFIED`.

<!--
これは`source`へ`balance`を送るoperationを返すMichelsonのプログラムに、`<<`と`>>`で囲まれた注釈を付与したコードです。
ContractAnnotと書かれた注釈には、プログラムの終了状態のstackに積まれた値`(ops, _)`に対し、`ops = [TransferTokens Unit balance addr]`を満たすことが記述されています。
プログラム中にはスタックトップが`None`のときに例外を送出する`ASSERT_SOME`がありますが、`source`のaddressが指すアカウントは人間の操作するアカウントであるはずなので、`CONTRACT unit`は必ず`Some`を返すはずで、例外になることはないはずです。ContractAnnotには`{ exc | False }`の部分で例外の値の条件がFalse、つまり例外が起きないことを記述しています。
そしてこのソースコードに対して`tezos-client refinement boomerang.tz`を実行すると`VERIFIED`と出力されるでしょう
-->

## How it works

<!-- - ツールに投げるソースコードは言語 [Michelson](https://tezos.gitlab.io/whitedoc/michelson.html) で記述されたプログラムに、`<<`と`>>`で囲まれた注釈を付与したコードである必要があります -->

Helmholtz accepts a [Michelson](https://tezos.gitlab.io/whitedoc/michelson.html) program annotaed with its formal specification and hints (e.g., loop invariants) used by Helmholtz.  An annotation is surrounded by `<<` and `>>`.

Helmholtz works as follows.
- If `tezos-client refinement <src>` is executed, Helmholtz strips the annotations surrounded by `<<` and `>>` and typechecks the stripped code using `tezos-client typecheck`; the simple type checking is conducted in this step.
- After typechecking, `tezos-client refinement` generates verification conditions from annotations users give
    - Generated verification conditions can be shown in `.refx/out.smt2` or the directory given by `-l` option.
- At last, Helmholtz discharges the conditions with `z3` and outputs `VERIFIED` or `UNVERIFIED`.


## Spec of Assertion Language
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
RTYPE ::= { STACK | EXP }
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
	| EXP : SORT
	| []
	| EXP :: EXP
	| [EXP; EXP; ...]
	| match EXP with PATTERNS
OP ::= 
	| +
	| -
	| *
	| /
	| <
	| >
	| <=
	| >=
	| =
	| <>
	| &&
	| ||
	| mod
	| ::
	| ^
UOP ::=
	| - 
	| !
ACCESSER ::=
	| first
	| second
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
	| (SORT)
	| int
	| unit
	| nat 
	| mutez 
	| timestamp 
	| bool 
	| string
	| bytes 
	| key 
	| address 
	| signature 
	| key_hash 
	| operation
	| pair SORT SORT 
	| list SORT 
	| contract SORT 
	| option SORT 
	| or SORT SORT 
	| map SORT SORT 
	| set SORT SORT
	| lambda SORT SORT
	| exception
```

#### Constructors
Some constructors in patterns need a type parameter `<ty>`. On the other hand, constructors in exp should not have `<ty>` (`ty` will be infered).

- `Nil` : list 'a
- `Cons` : 'a -> list 'a -> list 'a
- `Left` : 'a -> or 'a 'b
- `Right` : 'a -> or 'b 'a
- `Some` : 'a -> option 'a
- `None` : option 'a
- `Pair` : 'a -> 'b -> pair 'a 'b
- `True` : bool
- `False` : bool
- `Unit` : unit
- `Pack` <ty> : ty -> bytes
    - It corresponds to `PACK`, `UNPACK` in Michelson. It is expressed by a constructor because it needs type information.
- `Contract` <ty> : address -> contract ty
- `SetDelegate` : option key -> operation
- `TransferTokens`(Transfer) <ty> : ty -> mutez -> contract ty -> operation
- `CreateContract` <ty> : option address -> mutez -> ty -> address -> operation
    - `CreateContract ka tz stor addr` means a operation if the stack is `ka : tz : stor : S` , `CREATE_CONTRACT` is executed, and transition to `addr : op : S`
    
- `Error` <ty> : ty -> exception
    - Exceptions raised by `FAILWITH` instruction
- `Overflow` : exception
    - Overflow exception such as multiplications of mutez.

#### Built-in Instructions
- `not` : bool -> bool
- `get_str` : string -> int -> string
    - `get_str s i` returns i-th character of s as a single string.
- `sub_str` : string -> int -> int -> string
    - `sub_str s i l` returns a substring of s from i-th with the length of l
- `len_str` : string -> int
    - Return the length of the string
- `concat_str` : string -> string -> string
    - Concat the two strings. Same as `^` operator.
- `get_bytes` : bytes -> int -> bytes
- `sub_bytes` : bytes -> int -> int -> bytes
- `len_bytes` : bytes -> int
- `concat_bytes` : bytes -> bytes -> bytes
    - Concat the two bytes.
- `first` : pair 'a 'b -> 'a
- `second` : pair 'a 'b -> 'b
- `find_opt` : 'a -> map 'a 'b -> option 'b
    - `find_opt k m` indexes k from m and return `Some v` if v associated with k is exists. If not, return `None`
- `update` : 'a -> option 'b -> map 'a 'b -> map 'a 'b
    - `update k (Some v) m` updates the value associated with k into v in map m. `update k None m` deletes the value associated with k from m.
- `empty_map` : map 'a 'b
- `mem` : 'a -> set 'a -> bool
- `add` : 'a -> set 'a -> set 'a
- `remove` : 'a -> set 'a -> set 'a
- `empty_set` : set 'a
- `source` : address
    - Corresponding to `SOURCE` in Michelson.
- `sender` : address
    - Corresponding to `SENDER` in Michelson.
- `self` : contract parameter_ty
    - Corresponding to `SELF` in Michelson.
- `now` : timestamp
    - Corresponding to `NOW` in Michelson.
- `balance` : mutez
    - Corresponding to `BALANCE` in Michelson.
- `amount` : mutez
    - Corresponding to `AMOUNT` in Michelson.
- `call` : fun 'a 'b -> 'a -> 'b -> bool
    - `call` is a function where `call f a b` is  returns true if, when the function f created by LAMBDA is applied to argument a, it terminates, and the return value is b. Otherwise it is false.
- `hash` : key -> address
    - Corresponding to `HASH` in Michelson.
- `blake2b` : bytes -> bytes
    - Corresponding to `BLAKE2B` in Michelson.
- `sha256` : bytes -> bytes
    - Corresponding to `SHA256` in Michelson.
- `sha512` : bytes -> bytes
    - Corresponding to `SHA512` in Michelson.
- `sig` : key -> signature -> bytes -> bool
    - Corresponding to `CHECK_SIGNATURE` in Michelson.

### Annotation
A refinement type in the form of `{ stack | exp }` in annotations is a pair of a stack in the program and a verification condition for this stack.

There are 6 types of annotations below.
- `ContractAnnot rtype1 -> rtype2 & rtype3 vars`
    - Execute the program with the pre-condition `rtype1`, and if it ends successfully, the post-condition `rtype2` is satisfied, and if an exception is raised, make sure the exception value satisfies `rtype3`.
    - `rtype1` is a pre-condition for the stack (=`[pair parameter_ty storage_ty]`) when the program starts.
    - `rtype2` is a post-condition for the stack (=`[pair (list operation) storage_ty]`) when the program ends.
    - `rtype3` is a refinement type for the value the exception the program may throw has.
    - It is possible to declare some variables in `vars` that can be used in annotation inside the program.
        - Can not use these in the `rtype1`, `rtype2`, and `rtype3`.
    - A `ContractAnnot` annotation Must be written just before `code`
- `LambdaAnnot rtype1 -> rtype2 & rtype3 tvars`
    - Execute the function stacked by `LAMBDA` with the pre-condition `rtype1`, and if it ends successfully, the post-condition `rtype2` is satisfied, and if an exception is raised, make sure the exception value satisfies `rtype3`.
    - `rtype1` is a pre-condition for the stack (=`[pair parameter_ty storage_ty]`) when the function starts.
    - `rtype2` is a post-condition for the stack (=`[pair (list operation) storage_ty]`) when the function ends.
    - `rtype3` is a refinement type for the value the exception the function may throw has.
    - It is possible to declare some variables in `vars` that can be used in annotation inside the function.
        - Can not use these in the `rtype1`, `rtype2`, and `rtype3`.
    - A `ContractAnnot` annotation Must be written just before `LAMBDA`.
- `Assert rtype`
    - It checks the stack at the point where  `Assert` is wrriten satisfies the verification condition given by `rtype`.
    - It is possible to place between any two instructions.
- `Assume rtype`
    - It give the assumption for the stack by `rtype`.
    - It is possible to place between any two instructions.
- `LoopInv rtype`
    - It give a loop invariant by `rtype`
    - It checks the stack before and after the loop satisfies the verification condition.
    - **All the conditions assumed before the loop are gone after the loop, except those described in `LoopInv`.**
    - A `LoopInv` annotation Must be written just before `LOOP`, `ITER`
        - `MAP`, `LOOP_LEFT` are not yet supported
- `Measure`
    - A feature to give some specification of list, set and map
    - If you want, `Measure` annotations should be written  before `ContractAnnot`


#### Details
- `Key`, `Address`, `Signature` are not defined as constructors. This is because we don't want to deconstruct the `key`, `address`, and `signature` values into a string or bytes.
- The `str` in `Timestamp str` accepts an RFC3339-compliant string.
- The current annotation language does not distinguish between `int` and `nat`, `mutez`, and `timestamp` at the type level.
- Operator precedence is OCaml compliant.
- `LOOP_LEFT`, `APPLY`, (`LSL`, `LSR`, `AND`, `OR`, `XOR`, `NOT` as bit operations), `MAP`, (`SIZE` for map, set, and list), `CHAIN_ID`, and deprecated instructions are not yet supported.

### Q&A
- Error `misaligned expression` is output
    - It is not an error output by Helmholtz, but an error by indent-check by Michelson `tezos-client typecheck`. For the rules of indentation, see [here](https://tezos.gitlab.io/whitedoc/micheline.html).

## Examples
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

The program can raise exceptions to `Error Unit` and `Error 0` in two places: `ASSERT`, `PUSH int 0; FAILWITH`, respectively. In this example, allowing exceptions makes the post-condition stronger. This program checks the signature given by the parameter is valid and the contract the address in storage pointing to has type `contract string`. If either of them fails, the above exception is raised. If the execution terminates successfully, both of them should be satisfied  and they are written in the post-condition.

<!--
このプログラムでは`ASSERT`, `PUSH int 0; FAILWITH`の二箇所からそれぞれ`Error Unit`, `Error 0`の例外が送出され得ます。ContractAnnotでは、この2つの例外が起こりうることを記述しています。
この例では例外が起こりうることを許容することで事後条件にはより強い主張ができています。上のプログラムでは引数のsignatureの検証、storage上のaddressの指すコントラクトの引数型チェックをしており、それぞれ失敗すると上記の例外が出るわけですが、このプログラムが正常終了した場合はどちらもうまくいっているはずであり、事後条件にはそのことが記述されています。
-->

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
This example is an introduction to the environment variables, `Assume`, `LoopInv` and `Measure`. The program first defines the sum of all elements in `list int` by `Measure` at the beginning. Next, `Assume` assigns the value of the stack at that point to the variable `l`, declared in the end of `ContractAnnot`. `LoopInv` gives the loop-invariant for `ITER`. `ITER { ADD }` is an instruction that adds the head of the list to `s` the second from the top of the stack. The loop-invariant condition `s + sumseq r = sumseq l` expresses that adding `s` to the sum of list `r` in process equals the sum of the list `l`. The condition written in Assume are lost after going through LoopInv. I add `l = first arg` to the loop-invariant condition so that the condition for the value of `l` is not forgotten.

<!--
この例は環境変数, Assume, LoopInv, Measureの紹介です。
このプログラムは、まず先頭で list int の要素を全て足した値を Measure によって定義しています。
次に Assume によってその時点での stack の値を環境変数`l`に結びつけています。この`l`は ContractAnnot の末尾で定義されたものです。
そして LoopInv によって ITER 中でのループ不変条件を与えます。`ITER { ADD }`は、list の先頭をスタックの先頭から2番目`s`に全て足す命令です。ループ不変条件`s + sumseq r = sumseq l`は、処理中のリスト`r`の総和に`s`を足すと、最初のリスト`l`の総和と等しくなるということが表現されています。
LoopInvを経るとそれまでの仮定が失われてしまうので、Assumeで書いた条件は忘れられています。なので`l = first arg`をループ不変条件に追加して、`l`の値の条件が忘れられないようにしています。
-->