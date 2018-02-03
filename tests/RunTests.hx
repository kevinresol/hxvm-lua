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
		asserts.assert(compare(Success(null), lua.run('return null')));
		asserts.assert(compare(Success(null), lua.run('return nil', {nil: null})));
		return asserts.done();
	}
	
	public function integer() {
		asserts.assert(compare(Success(1), lua.run('return 1')));
		asserts.assert(compare(Success(3), lua.run('return 1 + 2')));
		asserts.assert(compare(Success(12), lua.run('return 3 * 4')));
		asserts.assert(compare(Success(1), lua.run('return num', {num: 1})));
		return asserts.done();
	}
	
	public function float() {
		// asserts.assert(compare(Success(1.1), lua.run('return 1.1'))); // FAIL: precision problem
		asserts.assert(compare(Success(1.125), lua.run('return 1.125')));
		asserts.assert(compare(Success(1.125), lua.run('return num', {num: 1.125})));
		return asserts.done();
	}
	
	public function string() {
		asserts.assert(compare(Success('a'), lua.run('return "a"')));
		asserts.assert(compare(Success('a'), lua.run('return str', {str: "a"})));
		return asserts.done();
	}
	
	public function object() {
		asserts.assert(compare(Success({}), lua.run('return {}')));
		asserts.assert(compare(Success({a:1, b:'2', c: {d: true}}), lua.run('return {a = 1, b = "2", c = {d = true}}')));
		asserts.assert(compare(Success({}), lua.run('return obj', {obj: {}})));
		asserts.assert(compare(Success({a:1, b:'2', c: {d: true}}), lua.run('return obj', {obj: {a:1, b:'2', c: {d: true}}})));
		return asserts.done();
	}
	
	public function array() {
		asserts.assert(compare(Success([0, 1, 2]), lua.run('return {0, 1, 2}')));
		asserts.assert(compare(Success([0, 1, 2]), lua.run('return arr', {arr: [0, 1, 2]})));
		return asserts.done();
	}
	
	public function func() {
		function add(a:Int, b:Int) return a + b;
		function mul(a:Int, b:Int) return a * b;
		
		
		asserts.assert(compare(Success(true), lua.run('return f()', {f: function() return true})));
		asserts.assert(compare(Success(3), lua.run('return add(1, 2)', {add: add})));
		asserts.assert(compare(Success(12), lua.run('return mul(3, 4)', {mul: mul})));
		asserts.assert(compare(Success(15), lua.run('return add(1, 2) + mul(3, 4)', {add: add, mul: mul})));
		
		lua.run('function add(a, b) \n return a + b \n end');
		asserts.assert(compare(Success(3), lua.call('add', [1, 2])));
		
		return asserts.done();
	}
	
	public function lib() {
		lua.loadLibs(['math']);
		asserts.assert(compare(Success(3), lua.run('return math.floor(3.6)')));
		return asserts.done();
	}
	
	public function err() {
		asserts.assert(!lua.run('invalid').isSuccess());
		asserts.assert(!lua.call('invalid', []).isSuccess());
		return asserts.done();
	}
}