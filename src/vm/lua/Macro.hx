package vm.lua;

import haxe.macro.Expr;

class Macro {
	public static macro function loopTable(l:Expr, v:Expr, body:Expr) {
		return macro {
			lua_pushnil($l);
			while(lua_next($l, $v < 0 ? $v - 1 : $v) != 0) {
				$body;
				lua_pop($l, 1);
			}
		}
	}
}