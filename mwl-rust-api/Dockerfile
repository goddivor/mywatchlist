FROM rust:slim AS builder

WORKDIR /builder

RUN apt-get update \
	&& apt-get install -y --no-install-recommends pkg-config libssl-dev \
	&& rm -rf /var/lib/apt/lists/*

COPY . .

RUN cargo build --release

FROM debian:bookworm-slim

RUN apt-get update \
	&& apt-get install -y --no-install-recommends ca-certificates libssl3 \
	&& rm -rf /var/lib/apt/lists/*

COPY --from=builder /builder/target/release/mwl-rust-api /mwl-rust-api

EXPOSE 8001

USER nobody:nogroup
CMD ["/mwl-rust-api"]
