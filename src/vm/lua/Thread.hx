package vm.lua;

#if cpp
@:headerCode('#include "linc_lua.h"')
#end
class Thread {
	public var ref(default, null):State;
	public function new(ref) this.ref = ref;
	
}