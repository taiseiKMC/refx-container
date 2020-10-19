[dockerhub](https://hub.docker.com/repository/docker/suginamiku/refx)

# build
- docker build . --build-arg COMMIT_HASH="hash" --squash

# usage
- `docker pull suginamiku/refx`
- `docker run -it -v DIR:/home/opam/tezos suginamiku/refx bash`
