FROM koalaman/shellcheck-alpine
WORKDIR /app
COPY logsentry/ .
RUN shellcheck bin/logsentry.sh

FROM alpine:3.20
WORKDIR /app
COPY  --chown=sentry:sentry bin/ bin/
RUN apk update && apk add --no-cache bash jq gawk && rm -rf /var/cache/apk/*
RUN adduser -D -u 10001 sentry 
USER sentry
ENTRYPOINT [ "/app/bin/logsentry.sh" ]
HEALTHCHECK --interval=30s --timeout=3s --start-period=2s --retries=3 CMD [ "/app/bin/logsentry.sh", "--help" ]
CMD [ "--help" ]

