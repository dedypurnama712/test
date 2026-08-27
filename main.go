package main

import (
"fmt"
"net/http"
"os"
)

var version = "dev"

func rootHandler(w http.ResponseWriter, r *http.Request) {
fmt.Fprintf(w, "Hello, DevOps! version=%s\n", version)
}

func main() {
http.HandleFunc("/", rootHandler)

port := os.Getenv("PORT")
if port == "" {
port = "8080"
}

fmt.Println("listening on :" + port)

if err := http.ListenAndServe(":"+port, nil); err != nil {
fmt.Println(err)
}
}
