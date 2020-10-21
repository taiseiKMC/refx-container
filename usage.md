# Abstract

Helmholtz is a static verification tool for Michelson---a smart contract language used in Tezos blockchain protocol. This tool takes a Michelson program annotated with a user-defined specification written in the form of a refinement type as input; it then typechecks the program against the specification based on our refinement type system, discharging the generated verification conditions with an SMT solver Z3.
Helmholtz is implemented as a subcommand of `tezos-client`, which is the client of Tezos blockchain.

This artifact is a docker container that provides an environment in which Helmholtz can be run.  The artifact also includes sample Michelson programs so that one can quickly try Helmholtz and confirm that the results in the accompanying paper is reproducible.

# Licence

Copyright (c) 2020 Igarashi Lab.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. 

> Readme.txtここから
# Helmholtz

Helmholtz is a static verification tool for a stack-based programming language [Michelson](https://tezos.gitlab.io/whitedoc/michelson.html), a smart contract language used in [Tezos](https://tezos.gitlab.io/) blockchain protocol.  It verifies that a Michelson program satisfies a user-written formal specification.


## Quickstart
To verify `src.tz` in <path-in-the-host> directory, sequentially execute the following commands in the host.
```
% unzip helmholtz.zip
% tar zxvf helmholtz/docker-19.03.9.tgz
% sudo cp docker/* /usr/bin
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
% sudo cp docker/* /usr/bin                         # Install Docker
% sudo dockerd &                                    # Run docker daemon
% sudo docker load --input helmholtz/helmholtz.img  # Load the container
```

And the following commands reproduce Table 1 in the paper. (Output time depends on the environment)
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

- `sudo docker run -it helmholtz <command>` will run `<command>` running in an environment that can execute Helmholtz.
    - If you want to work in the container, execute `bash` as `<command>`
    - To share a directory with the host, run `docker run -it -v <path-in-the-host>:/home/opam/ReFX/mount helmholtz <command>`
    - Tezos should be running in a sandbox inside the container.
- To verify an annotated Michelson program `src.tz`, run `tezos-client refinement src.tz`.  You can write a s dirctly as a string instead of the file name `src.tz`.
    - Annotations are to give a formal specification (i.e., an intended behavior) and hints (e.g., a loop invariant) to a Michelson program.  See below for a detail.
- You can execute any subcommand of `tezos-client` (cf., [Tezos Whitedoc](https://tezos.gitlab.io/api/cli-commands.html?highlight=tezos%20client))
    - The version of the tezos running in the container is `005_PsBabyM1 Babylon`.


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

+ The pair `(ops, _)`, which is in the stack at the end of the program, satisfies `ops = [TransferTokens Unit balance addr]`; this operation means that this contract will send money amount `balance` to `addr` with argument `Unit` after this contract finishes.
+ No exceptions are raised from the instructions in this program; this is expressed by the part `... & { exc | False }`.  There is an `ASSERT_SOME` instruction in the program that may raise an exception when the stack top is `None`, but since, from the specification of Michelson, the account pointed to by `source` should be a human-operated account, the `CONTRACT unit` should always return `Some`, so no exception will be raised. 

If you run `tezos-client refinement boomerang.tz`, you will get `VERIFIED`.


## How Helmholtz works

Helmholtz accepts a [Michelson](https://tezos.gitlab.io/whitedoc/michelson.html) program annotaed with its formal specification and hints (e.g., loop invariants) used by Helmholtz.  An annotation is surrounded by `<<` and `>>`.

Helmholtz works as follows.
- If `tezos-client refinement <src>` is executed, Helmholtz strips the annotations surrounded by `<<` and `>>` and typechecks the stripped code using `tezos-client typecheck`; the simple type checking is conducted in this step.
- After typechecking, `tezos-client refinement` generates verification conditions based on the type system described in the accompanying paper.
    - Generated verification conditions is stored in `.refx/out.smt2` or in the directory given by `-l` option.
- Then, Helmholtz discharges the conditions with `z3` and outputs `VERIFIED` or `UNVERIFIED`.

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

Some constructors in the pattern langauge require a type parameter `<ty>`, whereas constructors in `exp` do not.  (The type will be automatically infered).

The type of each constructor is as follows.

+ `Nil` : list 'a
+ `Cons` : 'a -> list 'a -> list 'a
+ `Left` : 'a -> or 'a 'b
+ `Right` : 'a -> or 'b 'a
+ `Some` : 'a -> option 'a
+ `None` : option 'a
+ `Pair` : 'a -> 'b -> pair 'a 'b
+ `True` : bool
+ `False` : bool
+ `Unit` : unit
+ `Pack` <ty> : ty -> bytes
    + A value with this constrcutor corresponds to a value created by the instruction `PACK` in Michelson.  It is expressed by a constructor because it needs type information.
+ `Contract` <ty> : address -> contract ty
+ `SetDelegate` : option key -> operation
+ `TransferTokens`(Transfer) <ty> : ty -> mutez -> contract ty -> operation
+ `CreateContract` <ty> : option address -> mutez -> ty -> address -> operation
+ `Error` <ty> : ty -> exception
    - Represents an exception raised by `FAILWITH` instruction.
+ `Overflow` : exception
    - Represents an overflow exception.

#### Built-in Instructions
- `not` : bool -> bool
- `get_str` : string -> int -> string
    - `get_str s i` returns i-th character of s as a single string.
- `sub_str` : string -> int -> int -> string
    - `sub_str s i l` returns a substring of s from i-th with the length of l.
- `len_str` : string -> int
    - Returns the length of the string.
- `concat_str` : string -> string -> string
    - Concatenates the two strings.  Same as `^` operator.
- `get_bytes` : bytes -> int -> bytes
- `sub_bytes` : bytes -> int -> int -> bytes
- `len_bytes` : bytes -> int
- `concat_bytes` : bytes -> bytes -> bytes
    - Concatenates two `bytes` values.
- `first` : pair 'a 'b -> 'a
- `second` : pair 'a 'b -> 'b
- `find_opt` : 'a -> map 'a 'b -> option 'b
    - `find_opt k m` looks for an entry associated with key `k` from map `m`; it returns `Some v` if `v` associated with `k` in `m`; returns `None` otherwise.
- `update` : 'a -> option 'b -> map 'a 'b -> map 'a 'b
    - `update k (Some v) m` updates the value associated with `k` in `m` to `v`; `update k None m` deletes the value associated with `k` from `m`.
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
    - `call f a b`, where `f` returns `true` if the application of function `f` created by `LAMBDA` to argument `a` terminates and evaluates to `b`; `false` otherwise.
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

In the following explanations of annotations, `rtype` represents a refinement type `{ stack | exp }` a pattern that maches a stack; `exp` is an expression of type `bool`.  It represents a `stack` in which `exp` evaluates to `true`.

There are 6 types of annotations below.
- `ContractAnnot rtype1 -> rtype2 & rtype3 vars`
    - This annotation gives the specification of a contract.  If this contract is executed with an initial stack that satisfies the pre-condition `rtype1`, and if it finishes its execution without exception, then the resulting stack satisfies the post-condition `rtype2`; if an exception is raised, then the exception value satisfies `rtype3`.
        - `rtype1` is a pre-condition for the stack (=`[pair parameter_ty storage_ty]`) when the program starts.
        - `rtype2` is a post-condition for the stack (=`[pair (list operation) storage_ty]`) when the program ends.
        - `rtype3` is a refinement type for the value the exception the program may throw has.
        - It is possible to declare ghost variables in `vars` that can be used in annotation inside the program.
            - The ghost variables can be used in the annotations in `code` section.  They cannot be used in `rtype1`, `rtype2`, and `rtype3`.
    - A `ContractAnnot` annotation must be placed just before a `code` section.
- `LambdaAnnot rtype1 -> rtype2 & rtype3 tvars`
    - This annotation gives the specification of a function that is created by an instruction `LAMBDA`.  A `LAMBDA` instruction associated with an annotation `LambdaAnnot rtype1 -> rtype2 & rtype3 tvars` should behave as if it is a contract annoted with `ContractAnnot rtype1 -> rtype2 & rtype3`.
    - A `LambdaAnnot` annotation must be placed just before `LAMBDA`.
- `Assert rtype`
    - It asserts that the stack at the program point where this annotation is placed satisfies `rtype`.
    - An assertion is checked by Helmholtz; if it is not verified, then the result of Helmholtz will be `UNVERIFIED`.
- `Assume rtype`
    - It assumes that the stack at the program point where this annotation is placed satisfies `rtype`.
    - Helmholtz assumes that a correct assumption is given.  It is user's responsibility to make sure that the assumption is correct.  If a wrong assumption is given, the verification result may not be reliable.
- `LoopInv rtype`
    - This annotation declares a loop invariant.  It is placed just before `LOOP` and `ITER` and specifies that the stack at the beginning of each iteration satisfies `rtype`.
    - A `LoopInv` annotation must be placed just before `LOOP`, `ITER`
        - `MAP`, `LOOP_LEFT` are not yet supported
- `Measure`
    - This annotation defines a (recursive) function over a list, a set, or a map that can be used in annotations.
    - `Measure` annotations should be placed before `ContractAnnot`.


#### Details
- `Key`, `Address`, `Signature` are not defined as constructors.  This is because we don't want to deconstruct the `key`, `address`, and `signature` values into a string or bytes.
- The `str` in `Timestamp str` accepts an RFC3339-compliant string.
- The current annotation language does not distinguish between `int` and `nat`, `mutez`, and `timestamp` at the type level.
- Operator precedence follows the convention of OCaml.
- `LOOP_LEFT`, `APPLY`, (`LSL`, `LSR`, `AND`, `OR`, `XOR`, `NOT` as bit operations), `MAP`, (`SIZE` for map, set, and list), `CHAIN_ID`, and deprecated instructions are not yet supported.
- Some relations between constants are not inferred automatically. For examples, despite the fact that `sha256 0x0 = 0x6e340b9cffb37a989ca544e6bb780a2c78901d3fb33738768511a30617afa01d` is true, Helmholtz will not verify this. If you need such properties, use `Assume`.
- When ITERate map or set, Helmholtz can not use the condition about the order of the iteration.
- Our source codes of Helmholtz is in `/home/opam/ReFX/src/proto_005_PsBabyM1/lib_refx` in the container.

### Q&A
- Error `misaligned expression` is output
    - It is not an error output by Helmholtz, but an error by indent-check by Michelson `tezos-client typecheck`. For the rules of indentation, see [here](https://tezos.gitlab.io/whitedoc/micheline.html).
- Error `MenhirBasics.Error` is output
    - This is an syntax error output by Helmholtz. Please check the annotations you give.

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

This program checks the signature given by the parameter is valid and the contract that the address in storage points to has type `contract string`; this behavior is described in the post-condition part of `ContractAnnot`.  The exception part in `ContractAnnot` expresses that the program can raise two kinds of exceptions: `Error Unit` in `ASSERT` and `Error 0` in `FAILWITH`.


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

This contract computes the sum of the integers in the list passed as a parameter.  The `ContractAnnot` annotation uses the function `sumseq`, which is defined in the earlier `Measure` annotation.  In the `code` section, the `Assume` annotation is used to specify that `l`, which is declared to be a ghost variable in the `ContractAnnot`, is the list passed as a parameter.  `LoopInv` gives the loop-invariant for `ITER`. `ITER { ADD }` is an instruction that adds the head of the list to the second `s` from the top of the stack. The loop-invariant condition `s + sumseq r = sumseq l` expresses that adding `s` to the sum of list `r` in process equals the sum of the list `l`.
