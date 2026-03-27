ARG ELIXIR_VERSION=1.18.3
ARG OTP_VERSION=27.3
ARG ALPINE_VERSION=3.21.3

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-alpine-${ALPINE_VERSION}"
ARG RUNNER_IMAGE="alpine:${ALPINE_VERSION}"

# --- Builder ---

FROM ${BUILDER_IMAGE} AS builder

RUN apk add --no-cache build-base git

WORKDIR /app

ENV MIX_ENV=prod

RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs mix.lock ./
RUN mix deps.get --only prod
RUN mkdir config
COPY config/config.exs config/prod.exs config/runtime.exs config/
RUN mix deps.compile

COPY lib lib
COPY priv priv
COPY assets assets

RUN mix assets.deploy
RUN mix compile

RUN mix release

# --- Runner ---

FROM ${RUNNER_IMAGE}

RUN apk add --no-cache libstdc++ openssl ncurses-libs

ENV MIX_ENV=prod

WORKDIR /app

RUN addgroup -S fate && adduser -S fate -G fate

COPY --from=builder --chown=fate:fate /app/_build/prod/rel/fate ./

USER fate

CMD ["sh", "-c", "bin/fate eval 'Fate.Release.migrate()' && bin/fate start"]
