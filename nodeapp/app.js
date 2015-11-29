var io = require('socket.io')(8080);
var userHash = {};

io.on('connection', function (socket) {

    console.log(socket.id + ' has connected!');

    // 接続開始カスタムイベント(接続元ユーザを保存し、他ユーザへ通知)
    socket.on("connected", function (name) {
      var msg = name + "が入室しました";
      console.log(msg);
      userHash[socket.id] = name;
      io.sockets.emit("publish", [msg]);
    });

    // メッセージ送信カスタムイベント
    socket.on("publish", function (data) {
      console.log("publish: " + data);
      io.sockets.emit("publish", data);
    });

    // 接続終了組み込みイベント(接続元ユーザを削除し、他ユーザへ通知)
    socket.on("disconnect", function () {
      if (userHash[socket.id]) {
        var msg = userHash[socket.id] + "が退出しました";
        console.log(msg);
        delete userHash[socket.id];
        io.sockets.emit("publish", msg);
      }
    });

});
