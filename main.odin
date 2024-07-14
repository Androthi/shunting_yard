package main

import "core:fmt"
import que "core:container/queue"
import "core:strconv"
import "core:os"
import "core:strings"

OP :: struct {
	precedence	:u8,
	num_args	:u8,
}

Attr_Type :: enum {
	null,
	Paren_Open,
	Paren_Close,
	Numeric,
	Operator,
}

Symbol :: union {
	rune,
	f64,
}

Attr :: struct {
	symbol	: Symbol,
	type	: Attr_Type,
	op		: OP,
}

// map order of precedence
mops := map[rune] OP {
	'-' = {1,2}, // when used as neg, num_args is set to 1
	'+' = {2,2},
	'*' = {3,2},
	'/' = {4,2},
}

main :: proc() {

	buf		:[300]byte
	result	:f64
	str		:string

	fmt.println("Shunting yard repl, enter 'q' to quit")
	fmt.println("this is a simple example, accepts single digits only")

	for {
		fmt.print("->")
		n, err := os.read(os.stdin, buf[:])
		if err < 0 {
			fmt.println("unable to read input")
		}
		if buf[0] == 'q' do break
		str = string(buf[:n])
		str = strings.trim_space(str)
		if len(str) > 0 do fmt.println("Result :", eval(str))
	}
	return
}

eval	:: proc( expr: string) -> f64 {

	strbuf		: [100]byte
	prev_symbol := Attr{0, .Operator, {0,0}}
	hold_stack	:que.Queue(Attr) // this doesn't need to be a queue, but makes it simpler this way
	output_stack:que.Queue(Attr)
		
	que.init(&hold_stack, 32)
	defer que.destroy(&hold_stack)
	que.init(&output_stack, 32)
	defer que.destroy(&output_stack)

	for character in expr {
		switch character {
			case '0'..='9':
				que.push_back(&output_stack, Attr{strconv.atof(fmt.bprint(strbuf[:],character)), .Numeric, {}} )
				prev_symbol = que.back(&output_stack)
			
			case '(':
				que.push_front(&hold_stack, Attr{character, .Paren_Open, {}})
				prev_symbol = que.front(&hold_stack)

			case ')':
				for que.len(hold_stack) != 0 && que.front(&hold_stack).type != .Paren_Open {
					que.push_back(&output_stack, que.front(&hold_stack))
					que.pop_front(&hold_stack)
				}
				if que.len(hold_stack)==0 {
					fmt.println("Error, Unexpected parenthesis :", character)
					return 0
				}

				if que.front(&hold_stack).type == .Paren_Open do que.pop_front(&hold_stack)

				prev_symbol = Attr { character, .Paren_Close, {}}

			case:
				op, ok := mops[character]
				if ok {
					if character == '-' || character == '+' {
						if prev_symbol.type != .Numeric && prev_symbol.type != .Paren_Close {							
							op.num_args = 1
							op.precedence = 10
						}
					}
					for que.len(hold_stack) != 0  && que.front(&hold_stack).type != .Paren_Open{
						if que.front(&hold_stack).type == .Operator {
							holding_stack_op := que.front(&hold_stack).op
							if( holding_stack_op.precedence >= op.precedence) {
								que.push_back(&output_stack, que.front(&hold_stack))
								que.pop_front(&hold_stack)
							}
							else do break
						}
					}

					que.push_front(&hold_stack, Attr {character, .Operator, op})
					prev_symbol = que.front(&hold_stack)
				}
				else {
					fmt.println("Bad Attr :", character)
					return 0
				}
		}
	}

	//flush hold stack
	for que.len(hold_stack) != 0 {
		que.push_back(&output_stack, que.front(&hold_stack))
		que.pop_front(&hold_stack)
	}

/*
	// for debug
	{
		fmt.println("Expression :", expr)
		fmt.print("RPN := ")
		for x := 0; x < que.len(output_stack); x+=1 {
			fmt.print( que.get(&output_stack, x).symbol)
		}
		fmt.println()
	}
*/

	// solver
	solve_stack :[dynamic]f64
	defer delete(solve_stack)
	sym:Attr
	args:[2]f64
	result:f64
	ok:bool

	for x:=0; x<que.len(output_stack); x+=1 {
		sym = que.get(&output_stack, x)
		#partial switch sym.type {
			case .Numeric:
				append(&solve_stack, sym.symbol.(f64))
			case .Operator:
				if len(solve_stack) < int(sym.op.num_args) {
					fmt.println("Error: not enough arguments")
					break
				}
				
				result = 0.0
				if sym.op.num_args == 1 {
					args[0] = pop(&solve_stack)
					if sym.symbol == '+' do result = +args[0]
					if sym.symbol == '-' do result = -args[0]
				}
				if sym.op.num_args == 2 {
					args[0] = pop(&solve_stack)
					args[1] = pop(&solve_stack)
					if sym.symbol == '-' do result = args[1]-args[0]
					if sym.symbol == '+' do result = args[1]+args[0]
					if sym.symbol == '*' do result = args[1]*args[0]
					if sym.symbol == '/' do result = args[1]/args[0]
				}

				append(&solve_stack, result)

			case:
				fmt.println("Unexpected type :", sym.type)
				return 0
		}
	}

	result = pop(&solve_stack)
	return result
}
