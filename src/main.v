module main
import io
import net
import os
import rand
import time
import term
import readline
import strconv

struct Player {
	mut:
		username 	string
		is_host 	int
		dest_ip 	string
		socket		net.TcpConn
}

struct Board {
	mut:
		p_board [][]int
		f_board [][]int
		p_score []int
		f_score []int
		playing bool
}

fn main() {
	rand.seed([u32(time.now().second), u32(time.now().second)])
	mut player := Player {
		username: "NoName"
		is_host: -1
	}
	filter_args(os.args, mut player)
	if player.is_host == -1 {
		println("Wrong argument passed to the program. You might have put -h and -c all together")
	}
	if player.is_host == 1 {
		mut socket := start_server(mut player)!
		println("Your friend just called you, let's start the game !")
		host_game(mut socket, mut player)!
	}
	if player.is_host == 0 {
		mut socket := connect_server(mut player)!
		println("Your friend is ready, let him grab the game board and the dices...")
		client_game(mut socket, mut player)!
	}
}

fn host_game(mut socket net.TcpConn, mut player Player)! {
	mut friend := Player {
		username: "NoName"
	}
	mut kb := Board {
		p_board: [[]int{cap: 3}, []int{cap: 3}, []int{cap: 3}]
		f_board: [[]int{cap: 3}, []int{cap: 3}, []int{cap: 3}]
		p_score: [0, 0, 0, 0]
		f_score: [0, 0, 0, 0]
		playing: false
	}
	defer {
		socket.close() or { panic(err) }
	}
	mut reader := io.new_buffered_reader(reader: socket)
	defer {
		unsafe {
			reader.free()
		}
	}
	friend.username = reader.read_line() or { return }
	socket.write_string("${player.username}\n")!
	mut starting := rand.choose([0, 1, 0, 1, 0, 1, 0, 1], 1)!
	if starting.pop() == 1 {
		kb.playing = true
		socket.write_string("0\n")!
		println("You start !")
	}
	else {
		socket.write_string("1\n")!
		println("${friend.username} start !")
	}
	for {
		online_game_loop(mut socket, mut kb, player, friend)!
		println("Asking your friend if he wants to play again...")
		if reader.read_line()! == "AGAIN" {
			kb = Board {
				p_board: [[]int{cap: 3}, []int{cap: 3}, []int{cap: 3}]
				f_board: [[]int{cap: 3}, []int{cap: 3}, []int{cap: 3}]
				p_score: [0, 0, 0, 0]
				f_score: [0, 0, 0, 0]
				playing: false
			}
		}
		else { break }
	}
}

fn client_game(mut socket net.TcpConn, mut player Player)! {
	mut friend := Player {
		username: "NoName"
	}
	mut kb := Board {
		p_board: [[]int{cap: 3}, []int{cap: 3}, []int{cap: 3}]
		f_board: [[]int{cap: 3}, []int{cap: 3}, []int{cap: 3}]
		p_score: [0, 0, 0, 0]
		f_score: [0, 0, 0, 0]
		playing: false
	}
	mut reader := io.new_buffered_reader(reader: socket)
	defer {
		unsafe {
			reader.free()
		}
	}
	socket.write_string("${player.username}\n")!
	friend.username = reader.read_line() or { return }
	if reader.read_line()! == "1" {
		kb.playing = true
		println("You start !")
	}
	else {
		println("${friend.username} start !")
	}
	for {
		online_game_loop(mut socket, mut kb, player, friend)!
		mut r := readline.Readline{}
		if r.read_line("Wants to play again (y/n) ? ")! == "y" {
			socket.write_string("AGAIN\n")!
			kb = Board {
				p_board: [[]int{cap: 3}, []int{cap: 3}, []int{cap: 3}]
				f_board: [[]int{cap: 3}, []int{cap: 3}, []int{cap: 3}]
				p_score: [0, 0, 0, 0]
				f_score: [0, 0, 0, 0]
				playing: false
			}
		}
		if reader.read_line()! == "AGAIN" {
		}
		else { break }
	}
}

fn online_game_loop(mut socket net.TcpConn, mut kb Board, player Player, friend Player)! {
	mut r := readline.Readline{}
	mut user_input := -1
	mut reader := io.new_buffered_reader(reader: socket)
	mut dice := 0
	mut end_game := 0
	for {
		get_score(mut kb)
		print_game(kb, player, friend)
		dice = get_dice()!
		if end_game == 1 {
			break
		}
		if kb.playing {
			for {
				user_input = r.read_line("Dice [${dice}] : ")!.int()
				if user_input == -1 { continue }
				if user_input >= 1 && user_input <= 3 {
					user_input--
					if insert_dice(mut kb, dice, user_input) {
						if check_end_game(kb) == true {
							end_game = 1
						}
						socket.write_string("${dice}-${user_input}-${end_game}\n")!
						break
					}
				}
			}
		}
		else {
			term.set_cursor_position(term.Coord{0, 10})
			println("${friend.username} is playing...")
			friend_move := reader.read_line() or { return }
			f_dice := strconv.atoi(friend_move[0].ascii_str())!
			f_pos := strconv.atoi(friend_move[2].ascii_str())!
			f_end := strconv.atoi(friend_move[4].ascii_str())!
			insert_dice(mut kb, f_dice, f_pos)
			end_game = f_end
		}
	}
	print_game(kb, player, friend)
	if kb.p_score[3] > kb.f_score[3] {
		println("You won the game !")
	}
	else if kb.p_score[3] < kb.f_score[3]{
		println("${friend.username} won the game !")
	}
	else {
		println("It's a draw !")
	}
}

fn get_dice()! int {
	mut dice := rand.choose([1, 2, 3, 4, 5, 6], 1)!
	return dice.pop()
}

fn get_score(mut kb Board) {
	for i in 0 .. 4 {
		if i == 3 {
			kb.p_score[3] = (kb.p_score[0] + kb.p_score[1] + kb.p_score[2]);
			kb.f_score[3] = (kb.f_score[0] + kb.f_score[1] + kb.f_score[2]);
		}
		else {
			kb.p_score[i] = get_col_score(kb.p_board[i]);
			kb.f_score[i] = get_col_score(kb.f_board[i]);
		}
	}
}

fn get_col_score(a []int) int {
	if a.len == 0 {
		return 0
	}
	sorted := a.sorted();
	if sorted.len == 1 {
		return sorted[0]
	}
	if sorted.len == 2 {
		if sorted[0] == sorted[1] {
			return (sorted[0] * 2) + (sorted[1] * 2)
		}
		return sorted[0] + sorted[1]
	}
	else {
		if sorted[0] == sorted[2] {
			return (sorted[0] * 3) + (sorted[0] * 3) + (sorted[0] * 3)
		}
		else if sorted[0] == sorted[1] {
			return (sorted[0] * 2) + (sorted[1] * 2) + sorted[2]
		}
		else if sorted[1] == sorted[2] {
			return sorted[0] + (sorted[1] * 2) + (sorted[2] * 2)
		}
		return sorted[0] + sorted[1] + sorted[2]
	}
}

fn insert_dice(mut kb Board, dice int, user_input int) bool {
	if kb.playing == true && kb.p_board[user_input].len != 3 {
		kb.p_board[user_input] << dice
		kb.f_board[user_input] = check_other_board(kb.p_board[user_input], mut kb.f_board[user_input])
		kb.playing = false
		return true
	}
	else if kb.playing == false && kb.f_board[user_input].len != 3 {
		kb.f_board[user_input] << dice
		kb.p_board[user_input] = check_other_board(kb.f_board[user_input], mut kb.p_board[user_input])
		kb.playing = true;
		return true
	}
	return false
}

fn check_other_board(a []int, mut b []int) []int {
	mut b_delete := []int{cap: 3};
	for a_elem in a {
		for i, b_elem in b {
			if a_elem == b_elem {
				b_delete << i;
			}
		}
	}
	for b_delete.len != 0 {
		b.delete(b_delete.pop());
	}
	return b
}

fn check_end_game(kb Board) bool {
	p_board := kb.p_board[0].len + kb.p_board[1].len + kb.p_board[2].len
	f_board := kb.f_board[0].len + kb.f_board[1].len + kb.f_board[2].len
	if p_board == 9 || f_board == 9 {
		return true
	}
	return false
}


fn start_server(mut player Player)!& net.TcpConn {
	mut server := net.listen_tcp(.ip6, ":1145")!
	host_ip := os.execute("curl ifconfig.me 2> /dev/null")
	eprintln("Waiting for your best friend to call you on this number : ${host_ip.output}")
	return server.accept()!
}

fn connect_server(mut player Player)!& net.TcpConn {
	println("Calling your best friend to see if he is ready to play a game...")
	return net.dial_tcp(player.dest_ip)!
}

fn print_game(kb Board, player Player, friend Player) {
	mut p_visual := []string{cap: 3}
	mut f_visual := []string{cap: 3}

	term.clear()
	term.set_cursor_position(term.Coord{0, 0})
	for i in 0 .. 3 {
		for elem in kb.p_board[i] {
			p_visual << elem.str()
		}
		for p_visual.len != 3 {
			p_visual << " "
		}
		for elem in kb.f_board[i] {
			f_visual << elem.str()
		}
		for f_visual.len != 3 {
			f_visual << " "
		}
		for j in 0..3 {
			term.set_cursor_position(term.Coord{1 + (i * 4), 3-j})
			print(term.red("|") + "${f_visual[j]}" + term.red("|"))
			term.set_cursor_position(term.Coord{1 + (i * 4), j+6})
			print(term.blue("|") + "${p_visual[j]}" + term.blue("|"))
		}

		for p_visual.len != 0 {
			p_visual.pop()
			f_visual.pop()
		}
	}
	term.set_cursor_position(term.Coord{15, 2})
	print("${friend.username} : ")
	println(term.red("${kb.f_score[3]}"))
	term.set_cursor_position(term.Coord{15, 7})
	print("${player.username} : ")
	println(term.blue("${kb.p_score[3]}"))
	term.set_cursor_position(term.Coord{2, 4})
	println(term.red("${kb.f_score[0]}"))
	term.set_cursor_position(term.Coord{2, 5})
	println(term.blue("${kb.p_score[0]}"))
	term.set_cursor_position(term.Coord{6, 4})
	println(term.red("${kb.f_score[1]}"))
	term.set_cursor_position(term.Coord{6, 5})
	println(term.blue("${kb.p_score[1]}"))
	term.set_cursor_position(term.Coord{10, 4})
	println(term.red("${kb.f_score[2]}"))
	term.set_cursor_position(term.Coord{10, 5})
	println(term.blue("${kb.p_score[2]}"))
	term.set_cursor_position(term.Coord{0, 10})
}

fn filter_args(args []string, mut player Player) {
	mut i := 1
	mut ret_val := -1
	for i < args.len {
		if args[i] == "-u" {
			i++
			player.username = args[i]
		}
		if args[i] == "-h" {
			if ret_val != -1 {
				player.is_host = -1
				return
			}
			player.is_host = 1
			player.dest_ip = "0.0.0.0"
		}
		if args[i] == "-c" && ret_val == -1 {
			if ret_val != -1 {
				player.is_host = -1
				return
			}
			i++
			player.is_host = 0;
			player.dest_ip = "${args[i]}" + ":1145"
		}
		i++
	}
	return
}
