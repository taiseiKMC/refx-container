FROM ocaml/opam2:debian-10-ocaml-4.07
USER root
RUN apt update
RUN apt install -y rsync git m4 build-essential patch unzip wget pkg-config libgmp-dev libev-dev libhidapi-dev libffi-dev jq curl
USER opam
WORKDIR /home/opam
RUN opam switch create 4.07.1 -y
RUN opam update
RUN opam install menhir -y
RUN curl -Lo z3.zip https://github.com/Z3Prover/z3/releases/download/z3-4.8.9/z3-4.8.9-x64-ubuntu-16.04.zip
RUN unzip z3.zip
ENV PATH $PATH:/home/opam/z3-4.8.9-x64-ubuntu-16.04/bin
RUN git clone https://gitlab.com/akawashiro/tezos.git
WORKDIR tezos
RUN git checkout origin/refx
RUN opam init --bare
RUN make build-deps
RUN eval $(opam env)
ARG COMMIT_HASH="157824a49a65854c8818a8fea592624c374dbdc8"
ENV PATH $PATH:/home/opam/tezos/_opam/bin:/home/opam/.opam/4.07.1/bin
RUN git fetch && git checkout origin/hsaito/new_lang
RUN make
ENV TEZOS_CLIENT_UNSAFE_DISABLE_DISCLAIMER "Y"

RUN opam clean -a
RUN rm -rf _opam/
WORKDIR ..
RUN opam clean -a
RUN rm -rf .opam/
WORKDIR tezos
COPY exec.sh /home/opam/tezos
ENTRYPOINT [ "/home/opam/tezos/exec.sh" ]