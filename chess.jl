using Pkg
Pkg.add(["Chess"]) 

function Shannon(b :: Board) :: Float32
	toMove = sidetomove(b)
	if isdraw(b) return 0f0 end	
	s=0f0
	if ischeck(b) == true
		s-= .5f0
		if ischeckmate(b) == true s -= 200f0 end
	else
		s += .05f0 * (movecount(b))
		info = donullmove!(b)
		s -= .05f0 * (movecount(b))
		undomove!(b, info)
	end
	attacks = SS_EMPTY
	for p ∈ pieces(b, toMove) attacks = attacks ∪ attacksfrom(b, p) end
	s += .1f0 * squarecount(attacks ∩ pieces(b, -toMove))
	if toMove == BLACK s=-s end
	
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
			return sort(moves, by = move -> in(to(move), oppPieces), rev=true)
		end
		vals[i] = getindex(tt, bs)
	end
	moves[sortperm(vals, rev=true)]
end

function minMax(b, root, depth, α, β, tt)
	bestMove = missing
	if depth == 0 || isterminal(b) return Shannon(b) end
	orderedMoves = orderMoves(b, moves(b), tt)
	if sidetomove(b) == WHITE
		bestVal = -Inf
		for move in orderedMoves
			u = domove!(b, move) 
			val = minMax(b, false, depth-1, α, β, tt)
			undomove!(b, u) 
			if val > bestVal
				bestVal = val
				if root bestMove = move end
			end
			α = max(α, val)
			if β < α break end
		end
	else
		bestVal = Inf
		for move in reverse(orderedMoves)
			u = domove!(b, move) 
			val = minMax(b, false, depth-1, α, β, tt)
			undomove!(b, u) 
			if val < bestVal
				bestVal = val
				if root bestMove = move end
			end
			β = min(β, val)
			if β < α break end
		end
	end
	tt[fen(b)] = bestVal
	if root return bestMove end
	return bestVal
end

function nextMove(b, depth)
	tt = Dict{String, Float32}()
	bestMove = missing
	for i in 1:depth bestMove = minMax(b, true, i, -Inf, Inf, tt) end
	bestMove
end

function runGameSF()
    g = SimpleGame()
	sf = runengine("stockfish")
	setoption(sf, "Hash", 256);
	setoption(sf, "UCI_LimitStrength", true)
	setoption(sf, "UCI_Elo", 2000)
    while true
		@info board(g)
		if isterminal(g) break end
		before = time();
		move=nextMove(board(g), 6)
		@info time() - before;
		domove!(g, move);

		@info board(g)
		if isterminal(g) break end
		setboard(sf, g)
		domove!(g, search(sf, "go depth 12").bestmove);		
	end
	@info g
	g
end

# g = runGameSF()