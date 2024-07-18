package ;

import tink.unit.*;
import tink.testrunner.*;
import deepequal.DeepEqual.*;

using tink.CoreApi;

@:asserts
class RunTests {

	static function main() {
		Runner.run(TestBatch.make([
			new RunTests(),
		])).handle(Runner.exit);
	}
	
	var lua:vm.lua.Lua;
	
	function new() {}
	
	@:before
	public function before() {
		lua = new vm.lua.Lua();
		return Noise;
	}
	
	@:after
	public function after() {
		lua.destroy();
		return Noise;
	}
	
	public function version() {
		asserts.assert(lua.version == 'Lua 5.3');
		return asserts.done();
	}
	
	public function nil() {
		asserts.assert(compare(Success(null), lua.tryRun('return null')));
		asserts.assert(compare(Success(null), lua.tryRun('return nil', {nil: null})));
		return asserts.done();
	}
	
	public function integer() {
		asserts.assert(compare(Success(1), lua.tryRun('return 1')));
		asserts.assert(compare(Success(3), lua.tryRun('return 1 + 2')));
		asserts.assert(compare(Success(12), lua.tryRun('return 3 * 4')));
		asserts.assert(compare(Success(1), lua.tryRun('return num', {num: 1})));
		return asserts.done();
	}
	
	public function float() {
		// asserts.assert(compare(Success(1.1), lua.tryRun('return 1.1'))); // FAIL: precision problem
		asserts.assert(compare(Success(1.125), lua.tryRun('return 1.125')));
		asserts.assert(compare(Success(1.125), lua.tryRun('return num', {num: 1.125})));
		return asserts.done();
	}
	
	public function string() {
		asserts.assert(compare(Success('a'), lua.tryRun('return "a"')));
		asserts.assert(compare(Success('a'), lua.tryRun('return str', {str: "a"})));
		return asserts.done();
	}
	
	public function object() {
		asserts.assert(compare(Success({}), lua.tryRun('return {}')));
		asserts.assert(compare(Success({a:1, b:'2', c: {d: true}}), lua.tryRun('return {a = 1, b = "2", c = {d = true}}')));
		asserts.assert(compare(Success({}), lua.tryRun('return obj', {obj: {}})));
		asserts.assert(compare(Success({a:1, b:'2', c: {d: true}}), lua.tryRun('return obj', {obj: {a:1, b:'2', c: {d: true}}})));
		asserts.assert(compare(Success(1), lua.tryRun('return obj.a', {obj: {a:1, b:'2', c: {d: true}}})));
		asserts.assert(compare(Success('2'), lua.tryRun('return obj.b', {obj: {a:1, b:'2', c: {d: true}}})));
		asserts.assert(compare(Success(true), lua.tryRun('return obj.c.d', {obj: {a:1, b:'2', c: {d: true}}})));
		return asserts.done();
	}
	
	public function array() {
		asserts.assert(compare(Success([0, 1, 2]), lua.tryRun('return {0, 1, 2}')));
		asserts.assert(compare(Success(0), lua.tryRun('return arr[1]', {arr: [0, 1, 2]})));
		asserts.assert(compare(Success([0, 1, 2]), lua.tryRun('return arr', {arr: [0, 1, 2]})));
		return asserts.done();
	}
	
	public function inst() {
		var foo = new Foo();
		lua.setGlobalVar('foo', foo);
		asserts.assert(compare(Success(1), lua.tryRun('return foo.a')));
		asserts.assert(compare(Success('2'), lua.tryRun('return foo.b')));
		asserts.assert(compare(Success(3), lua.tryRun('return foo.add(1, 2)')));
		asserts.assert(compare(Success(1), lua.tryRun('return foo.val()'))); // this make sure this-binding in js is working
		return asserts.done();
	}

	public function get() {
		lua.setGlobalVar('foo', new Foo());
		var foo:Foo = lua.getGlobalVar('foo');
		asserts.assert(compare(1, foo.val()));
		return asserts.done();
	}
	
	public function func() {
		function add(a:Int, b:Int) return a + b;
		function mul(a:Int, b:Int) return a * b;
		
		// call haxe function in lua
		asserts.assert(compare(Success(true), lua.tryRun('return f()', {f: function() return true})));
		asserts.assert(compare(Success(3), lua.tryRun('return add(1, 2)', {add: add})));
		asserts.assert(compare(Success(12), lua.tryRun('return mul(3, 4)', {mul: mul})));
		asserts.assert(compare(Success(15), lua.tryRun('return add(1, 2) + mul(3, 4)', {add: add, mul: mul})));
		
		// call lua function from haxe
		lua.tryRun('function add(a, b) return a + b end');
		asserts.assert(compare(Success(3), lua.tryCall('add', [1, 2])));
		
		// return lua function to haxe
		switch lua.tryRun('function sub(a, b) return a - b end return sub') {
			case Success(sub): asserts.assert((cast sub)(5, 2) == 3);
			case Failure(e): asserts.fail(e);
		}
		
		
		return asserts.done();
	}
	
	
	public function thread() {
		asserts.assert(compare(Success(new ClassInst(vm.lua.Thread)), lua.tryRun('return coroutine.create (function () print("co", coroutine.yield(1)) end)')));
		
		// hold a coroutine in haxe
		switch lua.tryRun('return coroutine.create (function () print("co", coroutine.yield(1)) end)') {
			case Success(co):
				asserts.assert(compare(Success({success: true, yield: 1}), lua.tryRun('success, yield = coroutine.resume(co); return {success = success, yield = yield}', {co: co})));
			case Failure(e):
				asserts.fail(e);
		}
		return asserts.done();
		
	}
	
	public function lib() {
		// lua.loadLibs(['math']); // all stdlib loaded by default
		asserts.assert(compare(Success(3), lua.tryRun('return math.floor(3.6)')));
		asserts.assert(compare(Success('a'), lua.tryRun('local t = {a = 1}; for k,v in pairs(t) do return k end')));
		return asserts.done();
	}
	
	public function err() {
		asserts.assert(!lua.tryRun('invalid').isSuccess());
		asserts.assert(!lua.tryCall('invalid', []).isSuccess());
		return asserts.done();
	}
}

@:keep
class Foo {
	var a = 1;
	var b = '2';
	public function new() {}
	public function add(a:Int, b:Int) return a + b;
	public function val() return a;
}

class ClassInst implements deepequal.CustomCompare {
	var cls:Class<Dynamic>;
	public function new(cls) 
		this.cls = cls;
	public function check(actual:Dynamic, compare:Dynamic->Dynamic->deepequal.Result):deepequal.Result {
		return Type.getClass(actual) == cls ? Success(Noise) : Failure({message: 'Expected cls ${Type.getClassName(cls)}', path: []});
	}
}