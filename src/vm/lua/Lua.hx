package vm.lua;

#if linc_lua
import vm.lua.Api.*;
#end

#if js
import fengari.Fengari.*;
import fengari.Lua.*;
import fengari.Lauxlib.*;
import fengari.Lualib.*;
import fengari.State;
#end

import vm.lua.Thread;
import vm.lua.Macro.*;
import haxe.DynamicAccess;

enum BadConversionBehavior {
	Silent;
	Warn;
	Throw;
}

#if cpp
@:headerCode('#include "linc_lua.h"')
#end
class Lua {
	public var version(default, never):String = VERSION;
	
	var l:State;
	static var funcs = [];
	
	public function new() {
		l = luaL_newstate();
		luaL_openlibs(l);
	}
	
	#if tink_core
	public function tryRun(s, ?g)
		return tink.core.Error.catchExceptions(run.bind(s, g));
	
	public function tryCall(n, a)
		return tink.core.Error.catchExceptions(call.bind(n, a));
	#end
	
	public function run(script:String, ?globals:DynamicAccess<Any>):Any {
		if(globals != null) for(key in globals.keys()) setGlobalVar(key, globals.get(key));
		if(luaL_dostring(l, script) == OK) return getReturnValues(l) else throw getErrorMessage(l);
	}
	
	public function call(name:String, args:Array<Any>):Any {
		lua_getglobal(l, name);
		for(arg in args) toLuaValue(l, arg);
		if(lua_pcall(l, args.length, 1, 0) == OK) return getReturnValues(l) else throw getErrorMessage(l);
	}
	
	public function loadLibs(libs:Array<String>) {
		for(lib in libs) {
			var openf:Dynamic =
				switch lib {
					case 'base': luaopen_base;
					case 'debug': luaopen_debug;
					case 'io': luaopen_io;
					case 'math': luaopen_math;
					case 'os': luaopen_os;
					case 'package': luaopen_package;
					case 'string': luaopen_string;
					case 'table': luaopen_table;
					case 'coroutine': luaopen_coroutine;
					case _: null;
				}
			if(openf != null) {
				luaL_requiref(l, lib, openf, true);
				lua_settop(l, 0);
			}
		}
	}
	
	public function setGlobalVar(name:String, value:Any) {
		toLuaValue(l, value);
		lua_setglobal(l, name);
	}
	
	public function unsetGlobalVar(name:String) {
		lua_pushnil(l);
		lua_setglobal(l, name);
	}
	
	public function getGlobalVar(name:String):Any {
		lua_getglobal(l, name);
		var v = toHaxeValue(l, -1);
		lua_pop(l, -1);
		return v;
	}
	
	public function destroy() {
		lua_close(l);
		l = null;
	}
	
	static function toLuaValue(l, v:Any, ?o:Any):Int {
		switch Type.typeof(v) {
			case TNull: lua_pushnil(l);
			case TBool: lua_pushboolean(l, v);
			case TFloat | TInt: lua_pushnumber(l, v);
			case TClass(String): lua_pushstring(l, (v:String));
			case TClass(Thread): 
				var th = (v:Thread).ref;
				lua_pushthread(th);
				lua_xmove(th, l, 1); // deduced from luaB_cocreate in lcorolib.c, basically reverse the action done there
			case TClass(Array):
				var arr:Array<Any> = v;
				lua_createtable(l, arr.length, 0);
				for(i in 0...arr.length) {
					lua_pushnumber(l, i + 1); // 1-based
					toLuaValue(l, arr[i], arr);
					lua_settable(l, -3);
				}
			case TFunction:
				#if cpp
				lua_pushnumber(l, funcs.push(v) - 1); // FIXME: this seems to leak like hell, but I have no idea how to store the function reference properly
				lua_pushcclosure(l, _callback, 1);
				#else
				lua_pushlightuserdata(l, o); // store the function context (js this)
				lua_pushlightuserdata(l, v);
				lua_pushcclosure(l, callback, 2);
				#end
			case TObject:
				lua_newtable(l);
				var obj:DynamicAccess<Any> = v;
				for(key in obj.keys()) {
					lua_pushstring(l, key);
					toLuaValue(l, obj.get(key), cast obj);
					lua_settable(l, -3);
				}
			case TClass(_):
				if(haxe.Int64.isInt64(v))
				{
					lua_pushinteger(l, v);
				}else{
					lua_newtable(l);
					for(key in Type.getInstanceFields(Type.getClass(v))) {
						lua_pushstring(l, key);
						toLuaValue(l, Reflect.getProperty(v, key), v);
						lua_settable(l, -3);
					}
				}
			case t: pushNilOrThrow(l, 'Cannot convert $t to Lua value');
		}
		return 1;
	}
	
	public static var badConversionBehavior(default, default):BadConversionBehavior = Warn;
	
	static function returnNullOrThrow(message:String) {
		switch (badConversionBehavior) {
			case Silent:
				return null;
			case Warn:
				trace('Warning: $message');
				return null;
			case Throw:
				throw message;
		}
	}

	static function pushNilOrThrow(l, message:String) {
		switch (badConversionBehavior) {
			case Silent:
				lua_pushnil(l);
			case Warn:
				trace('Warning: $message');
				lua_pushnil(l);
			case Throw:
				throw message;
		}
	}

	static function toHaxeValue(l, i:Int):Any {
		return switch lua_type(l, i) {
			case t if (t == TNIL): null;
			case t if (t == TNUMBER): lua_tonumber(l, i);
			case t if (t == TTABLE): toHaxeObj(l, i);
			case t if (t == TSTRING): (lua_tostring(l, i):String);
			case t if (t == TBOOLEAN): lua_toboolean(l, i);
			case t if (t == TFUNCTION): 
				switch lua_tocfunction(l, i) {
					case null: 
						lua_pushvalue(l, i); // copy to the top of stack for luaL_ref
						var ref = luaL_ref(l, REGISTRYINDEX);
						Reflect.makeVarArgs(function(args) {
							lua_rawgeti(l, REGISTRYINDEX, ref);
							for(arg in args) toLuaValue(l, arg);
							if(lua_pcall(l, args.length, 1, 0) == OK) return getReturnValues(l) else throw getErrorMessage(l);
						});
					case f: returnNullOrThrow('Cannot convert CFUNCTION to Haxe value');
				}
			case t if (t == TTHREAD): new Thread(lua_tothread(l, i));
			case t if (t == TUSERDATA): returnNullOrThrow('Cannot convert TUSERDATA to Haxe value');
			case t if (t == TLIGHTUSERDATA): returnNullOrThrow('Cannot convert TLIGHTUSERDATA to Haxe value');
			case t: returnNullOrThrow('unreachable ($t)');
		}
	}
	
	static function toHaxeObj(l, i:Int):Any {
		var count = 0;
		var array = true;
		
		loopTable(l, i, {
			if(array) {
				if(lua_type(l, -2) != TNUMBER) array = false;
				else {
					var index = lua_tonumber(l, -2);
					if(index < 0 || Std.int(index) != index) array = false;
				}
			}
			count++;
		});
		
		return 
		if(count == 0) {
			{};
		} else if(array) {
			var v = [];
			loopTable(l, i, {
				var index = Std.int(lua_tonumber(l, -2)) - 1;
				v[index] = toHaxeValue(l, -1);
			});
			cast v;
		} else {
			var v:DynamicAccess<Any> = {};
			loopTable(l, i, {
				switch lua_type(l, -2) {
					case t if(t == TSTRING): v.set(lua_tostring(l, -2), toHaxeValue(l, -1));
					case t if(t == TNUMBER):v.set(Std.string(lua_tonumber(l, -2)), toHaxeValue(l, -1));
				}
			});
			cast v;
		}
	}
	
	#if cpp
	static var _callback = cpp.Callable.fromStaticFunction(callback);
	#end
	
	static function callback(l) {
		#if cpp
		var l = cpp.Pointer.fromRaw(l);
		#end
		
		var numArgs = lua_gettop(l);
		#if cpp
			var o = null; // TODO
			var f = funcs[cast lua_tonumber(l, lua_upvalueindex(1))];
		#else
			var o = lua_topointer(l, lua_upvalueindex(1));
			var f = lua_topointer(l, lua_upvalueindex(2));
		#end
		var args = [];
		for(i in 0...numArgs) args[i] = toHaxeValue(l, i + 1);
		var result = Reflect.callMethod(o, f, args);
		return toLuaValue(l, result);
	}
	
	static function getReturnValues(l) {
		var lua_v:Int;
		var v:Any = null;
		while((lua_v = lua_gettop(l)) != 0) {
			v = toHaxeValue(l, lua_v);
			lua_pop(l, 1);
		}
		// returns the first value (in case of multi return) returned from the Lua function
		return v;
	}
	
	static function getErrorMessage(l) {
		var v:String = lua_tostring(l, -1);
		lua_pop(l, 1);
		return v;
	}
	
	static function printStack(l, depth:Int) {
		for(i in 1...depth + 1) {
			var t:String = lua_typename(l, lua_type(l, -i));
			var v = toHaxeValue(l, -i);
			trace(-i, t, v);
		}
	}
}


/**
 *  
 *  Stack is pushed downwards, i.e.:
 *    Push: add element to the top
 *    Pop: remove element from the top
 *  
 *  Visualization of the Stack:
 *  
 *  -- Top of stack, last pushed / newest element, index -1, index n
 *  --
 *  --
 *  --
 *  --
 *  -- Bottom of stack, first pushed / oldest element, index 1, index -n
 *  
 */
