using Pkg
Pkg.add(["Chess", "HTTP", "JSON"])

using Chess, HTTP, JSON

function Shannon(b::Board)::Float32
    toMove = sidetomove(b)
    if isdraw(b)
        return 0f0
    end
    s = 0f0
    if ischeck(b)
        s -= 0.5f0
        if ischeckmate(b)
            s -= 200f0
        end
    else
        s += 0.05f0 * movecount(b)
        info = donullmove!(b)
        s -= 0.05f0 * movecount(b)
        undomove!(b, info)
    end
    attacks = SS_EMPTY
    for p ∈ pieces(b, toMove)
        attacks = attacks ∪ attacksfrom(b, p)
    end
    s += 0.1f0 * squarecount(attacks ∩ pieces(b, -toMove))
    if toMove == BLACK
        s = -s
    end
    s += 9f0 * (squarecount(pieces(b, PIECE_WQ)) - squarecount(pieces(b, PIECE_BQ)))
    s += 5f0 * (squarecount(pieces(b, PIECE_WR)) - squarecount(pieces(b, PIECE_BR)))
    s += 3f0 * (squarecount(pieces(b, PIECE_WB)) - squarecount(pieces(b, PIECE_BB)))
    s += 3f0 * (squarecount(pieces(b, PIECE_WN)) - squarecount(pieces(b, PIECE_BN)))
    s += 1f0 * (squarecount(pieces(b, PIECE_WP)) - squarecount(pieces(b, PIECE_BP)))
    s
end

function orderMoves(b, moves, tt)
    vals = Vector{Float32}(undef, moves.count)
    for i in 1:moves.count
        u = domove!(b, moves[i])
        bs = fen(b)
        undomove!(b, u)
        if !haskey(tt, bs)
            oppPieces = pieces(b, -sidetomove(b))
            return sort(moves, by=move -> in(to(move), oppPieces), rev=true)
        end
        vals[i] = tt[bs]
    end
    moves[sortperm(vals, rev=true)]
end

function minMax(b, root, depth, α, β, tt)
    bestMove = missing
    if depth == 0 || isterminal(b)
        return Shannon(b)
    end
    orderedMoves = orderMoves(b, moves(b), tt)
    if sidetomove(b) == WHITE
        bestVal = -Inf
        for move in orderedMoves
            u = domove!(b, move)
            val = minMax(b, false, depth - 1, α, β, tt)
            undomove!(b, u)
            if val > bestVal
                bestVal = val
                if root
                    bestMove = move
                end
            end
            α = max(α, val)
            if β < α
                break
            end
        end
    else
        bestVal = Inf
        for move in reverse(orderedMoves)
            u = domove!(b, move)
            val = minMax(b, false, depth - 1, α, β, tt)
            undomove!(b, u)
            if val < bestVal
                bestVal = val
                if root
                    bestMove = move
                end
            end
            β = min(β, val)
            if β < α
                break
            end
        end
    end
    tt[fen(b)] = bestVal
    root ? bestMove : bestVal
end

function nextMove(b)
    tt = Dict{String,Float32}()
    bestMove = missing
    for i in 1:6
        bestMove = minMax(b, true, i, -Inf, Inf, tt)
    end
    bestMove
end

function handle_move(req::HTTP.Request)
    body = JSON.parse(String(req.body))
    b = fromfen(body["fen"])
    println("New board: ", b)
    move = nextMove(b)
    domove!(b, move)
    HTTP.Response(200, JSON.json(Dict("fen" => fen(b))))
end

const CORS = ["Access-Control-Allow-Origin" => "*",
    "Access-Control-Allow-Methods" => "POST",
    "Access-Control-Allow-Headers" => "Content-Type"]

function corsMiddleware(handler)
    return function (req::HTTP.Request)
        req.method == "OPTIONS" && return HTTP.Response(200, CORS)
        resp = handler(req)
        HTTP.setheader(resp, "Access-Control-Allow-Origin" => "*")
        resp
    end
end

const ROUTER = HTTP.Router()
HTTP.register!(ROUTER, "POST", "/api/move", handle_move)

println("Server up")
HTTP.serve(corsMiddleware(ROUTER), "0.0.0.0", 8080)
