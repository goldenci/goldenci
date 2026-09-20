package greet

import "testing"

func TestGreet(t *testing.T) {
	cases := []struct {
		name  string
		input string
		want  string
	}{
		{name: "named", input: "GoldenCI", want: "Hello, GoldenCI!"},
		{name: "empty falls back to world", input: "", want: "Hello, world!"},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if got := Greet(tc.input); got != tc.want {
				t.Errorf("Greet(%q) = %q, want %q", tc.input, got, tc.want)
			}
		})
	}
}
