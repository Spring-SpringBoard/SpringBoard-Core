#!/usr/bin/python3

# Echo server program
import socket
import logging
import json

logging.basicConfig(level=logging.INFO)
class SpringConnector(object):
    def __init__(self, host, port):
        self.host = host
        self.port = port
        self.callbacks = {}

    def register(self, name, callback):
        if name not in self.callbacks:
            self.callbacks[name] = []
        self.callbacks[name].append(callback)

    def send(self, command):
        self.conn.sendall(bytearray(json.dumps(command) + "\n", 'utf-8'))

    def fire(self, name, command):
        if name not in self.callbacks:
            logging.warning("No callback defined for command: {}".format(name))
            return

        for fn in self.callbacks[name]:
            try:
                fn(command)
            except Exception as ex:
                logging.error("Error while executing command: {}".format(name))
                import traceback
                tb = traceback.format_exc()
                logging.error(tb)

    def listen(self):
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        s.bind((self.host, self.port))
        s.listen(1)
        while True:
            logging.info("Waiting on connection at {}:{} ...".format(self.host, self.port))
            self.conn, addr = s.accept()
            self.clientAddress = addr
            logging.info('Connected by: {}'.format(self.clientAddress))
            while True:
                data = self.conn.recv(20971520)
                if not data:
                    break
                jsonData = json.loads(data.decode('utf-8'))
                print(jsonData)
                if "name" in jsonData:
                    command = jsonData.get("command")
                    if not command:
                        command = {}
                    self.fire(jsonData["name"], command)
            self.conn.close()
            logging.info('Connection closed')
