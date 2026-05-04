Chess engine I made while procrastinating for exams.
Can win against Stockfish engine when Stockfish is capped to 2000 ELO (although this needs further testing).

docker build -t server .
docker run -d -p 8080:8080 server  