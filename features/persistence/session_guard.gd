extends RefCounted
class_name SessionGuard

const SESSION_PORT: int = 44329
var _socket: TCPServer = TCPServer.new()


func acquire(port: int = SESSION_PORT) -> bool:
	return _socket.listen(port, "127.0.0.1") == OK


func release() -> void:
	_socket.stop()
