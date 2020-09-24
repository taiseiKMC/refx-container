FROM ocaml/opam2:debian-10-ocaml-4.07
USER root
RUN apt update
RUN apt install -y rsync git m4 build-essential patch unzip wget pkg-config libgmp-dev libev-dev libhidapi-dev libffi-dev jq curl
USER opam
WORKDIR /home/opam
RUN opam switch create 4.07.1 -y
RUN opam update
RUN opam install menhir -y
RUN git clone https://gitlab.com/akawashiro/tezos.git
WORKDIR tezos
RUN git checkout origin/refx
RUN opam init --bare
RUN make build-deps
RUN eval $(opam env)
ENV PATH $PATH:/home/opam/tezos/_opam/bin:/home/opam/.opam/4.07.1/bin
RUN make
WORKDIR ..
RUN curl -Lo z3.zip https://github.com/Z3Prover/z3/releases/download/z3-4.8.9/z3-4.8.9-x64-ubuntu-16.04.zip
RUN unzip z3.zip
ENV PATH $PATH:/home/opam/z3-4.8.9-x64-ubuntu-16.04/bin

RUN opam clean -a
WORKDIR tezos
RUN opam clean -a
RUN rm -rf _opam/
RUN rm -rf ../.opam/
COPY exec.sh /home/opam/tezos
ENTRYPOINT [ "/home/opam/tezos/exec.sh" ]