function carpetserver --wraps='tmux attach -t carpetserver || tmux new -s carpetserver -c ~/carpet-test-server "java -jar minecraft_server.1.12.2_carpet_test.jar --nogui"'
    tmux attach -t carpetserver; or tmux new -s carpetserver -c ~/carpet-test-server "/usr/lib/jvm/java-8-openjdk/bin/java -jar minecraft_server.1.12.2_carpet_test.jar --nogui"
end
