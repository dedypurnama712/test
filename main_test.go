package main

import (
"net/http"
"net/http/httptest"
"testing"
)

func TestRootHandler(t *testing.T) {
req := httptest.NewRequest(http.MethodGet, "/", nil)
rec := httptest.NewRecorder()

rootHandler(rec, req)

expected := "Hello, DevOps! version=dev\n"

if rec.Body.String() != expected {
t.Fatalf("expected %q, got %q", expected, rec.Body.String())
}
}

func TestRootHandlerStatusCode(t *testing.T) {
req := httptest.NewRequest(http.MethodGet, "/", nil)
rec := httptest.NewRecorder()

rootHandler(rec, req)

if rec.Code != http.StatusOK {
t.Fatalf("expected status %d, got %d", http.StatusOK, rec.Code)
}
}
