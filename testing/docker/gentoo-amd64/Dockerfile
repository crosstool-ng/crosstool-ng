FROM gentoo/stage3-amd64-hardened
RUN wget -O /sbin/dumb-init https://github.com/Yelp/dumb-init/releases/download/v1.2.1/dumb-init_1.2.1_amd64
RUN chmod +x /sbin/dumb-init
ENTRYPOINT [ "/sbin/dumb-init", "--" ]
