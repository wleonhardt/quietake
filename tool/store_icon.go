// Force the SVG-rendered Play icon to RGBA PNG without changing its pixels.
// Go's PNG encoder otherwise optimizes fully opaque images to RGB.
package main

import (
	"image"
	"image/color"
	"image/png"
	"log"
	"os"
)

type rgbaImage struct{ image.Image }

func (rgbaImage) ColorModel() color.Model { return color.NRGBAModel }
func (rgbaImage) Opaque() bool            { return false }

func main() {
	if len(os.Args) != 3 {
		log.Fatal("usage: go run tool/store_icon.go input.png output.png")
	}
	input, err := os.Open(os.Args[1])
	if err != nil {
		log.Fatal(err)
	}
	decoded, err := png.Decode(input)
	input.Close()
	if err != nil {
		log.Fatal(err)
	}
	if decoded.Bounds().Dx() != 512 || decoded.Bounds().Dy() != 512 {
		log.Fatal("Play icon must be 512 by 512 pixels")
	}
	output, err := os.Create(os.Args[2])
	if err != nil {
		log.Fatal(err)
	}
	if err := png.Encode(output, rgbaImage{decoded}); err != nil {
		log.Fatal(err)
	}
	if err := output.Close(); err != nil {
		log.Fatal(err)
	}
}
