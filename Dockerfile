FROM julia:latest
WORKDIR /app
COPY server.jl .
RUN julia -e 'using Pkg; Pkg.add(name="Chess", version="0.7.5"); Pkg.add(["HTTP", "JSON"])'
EXPOSE 8080
CMD ["server.jl"]