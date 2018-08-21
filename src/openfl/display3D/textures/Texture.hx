package openfl.display3D.textures; #if !flash


import haxe.io.Bytes;
import haxe.Timer;
import lime.utils.ArrayBufferView;
import lime.utils.UInt8Array;
import openfl._internal.formats.atf.ATFReader;
import openfl._internal.renderer.opengl.GLUtils;
import openfl._internal.renderer.SamplerState;
import openfl.display.BitmapData;
import openfl.events.Event;
import openfl.utils.ByteArray;

#if !openfl_debug
@:fileXml('tags="haxe,release"')
@:noDebug
#end

@:access(openfl.display3D.Context3D)
@:access(openfl.display.Stage)


@:final class Texture extends TextureBase {
	
	
	@:noCompletion private static var __lowMemoryMode:Bool = false;
	
	
	@:noCompletion private function new (context:Context3D, width:Int, height:Int, format:Context3DTextureFormat, optimizeForRenderToTexture:Bool, streamingLevels:Int) {
		
		super (context);
		
		__width = width;
		__height = height;
		//__format = format;
		__optimizeForRenderToTexture = optimizeForRenderToTexture;
		__streamingLevels = streamingLevels;
		
		var gl = __context.__gl;
		
		__textureTarget = gl.TEXTURE_2D;
		
		__context.__bindTexture (__textureTarget, __textureID);
		// GLUtils.CheckGLError ();
		
		gl.texImage2D (__textureTarget, 0, __internalFormat, __width, __height, 0, __format, gl.UNSIGNED_BYTE, #if (lime >= "7.0.0") null #else 0 #end);
		// GLUtils.CheckGLError ();
		
		__context.__bindTexture (__textureTarget, null);
		
	}
	
	
	public function uploadCompressedTextureFromByteArray (data:ByteArray, byteArrayOffset:UInt, async:Bool = false):Void {
		
		if (!async) {
			
			__uploadCompressedTextureFromByteArray (data, byteArrayOffset);
			
		} else {
			
			Timer.delay (function () {
				
				__uploadCompressedTextureFromByteArray (data, byteArrayOffset);
				dispatchEvent (new Event (Event.TEXTURE_READY));
				
			}, 1);
			
		}
		
	}
	
	
	public function uploadFromBitmapData (source:BitmapData, miplevel:UInt = 0, generateMipmap:Bool = false):Void {
		
		/* TODO
			if (LowMemoryMode) {
				// shrink bitmap data
				source = source.shrinkToHalfResolution();
				// shrink our dimensions for upload
				width = source.width;
				height = source.height;
			}
			*/
		
		if (source == null) return;
		
		var width = __width >> miplevel;
		var height = __height >> miplevel;
		
		if (width == 0 && height == 0) return;
		
		if (width == 0) width = 1;
		if (height == 0) height = 1;
		
		if (source.width != width || source.height != height) {
			
			var copy = new BitmapData (width, height, true, 0);
			copy.draw (source);
			source = copy;
			
		}
		
		var image = __getImage (source);
		if (image == null) return;
		
		// TODO: Improve handling of miplevels with canvas src
		
		#if (js && html5)
		if (miplevel == 0 && image.buffer != null && image.buffer.data == null && image.buffer.src != null) {
			
			var gl = __context.__gl;
			
			var width = texture.__width >> miplevel;
			var height = texture.__height >> miplevel;
			
			if (width == 0 && height == 0) return;
			
			if (width == 0) width = 1;
			if (height == 0) height = 1;
			
			__context.__bindTexture (texture.__textureTarget, texture.__textureID);
			// GLUtils.CheckGLError ();
			
			gl.texImage2D (texture.__textureTarget, miplevel, texture.__internalFormat, texture.__format, gl.UNSIGNED_BYTE, image.buffer.src);
			// GLUtils.CheckGLError ();
			
			__context.__bindTexture (texture.__textureTarget, null);
			// GLUtils.CheckGLError ();
			
			// var memUsage = (width * height) * 4;
			// __trackMemoryUsage (memUsage);
			return;
			
		}
		#end
		
		uploadFromTypedArray (image.data, miplevel);
		
	}
	
	
	public function uploadFromByteArray (data:ByteArray, byteArrayOffset:UInt, miplevel:UInt = 0):Void {
		
		#if (js && !display)
		if (byteArrayOffset == 0) {
			
			uploadFromTypedArray (texture, @:privateAccess (data:ByteArrayData).b, miplevel);
			return;
			
		}
		#end
		
		uploadFromTypedArray (new UInt8Array (data.toArrayBuffer (), byteArrayOffset), miplevel);
		
	}
	
	
	public function uploadFromTypedArray (data:ArrayBufferView, miplevel:UInt = 0):Void {
		
		if (data == null) return;
		
		var gl = __context.__gl;
		
		var width = __width >> miplevel;
		var height = __height >> miplevel;
		
		if (width == 0 && height == 0) return;
		
		if (width == 0) width = 1;
		if (height == 0) height = 1;
		
		__context.__bindTexture (__textureTarget, __textureID);
		// GLUtils.CheckGLError ();
		
		gl.texImage2D (__textureTarget, miplevel, __internalFormat, width, height, 0, __format, gl.UNSIGNED_BYTE, data);
		// GLUtils.CheckGLError ();
		
		__context.__bindTexture (__textureTarget, null);
		// GLUtils.CheckGLError ();
		
		// var memUsage = (width * height) * 4;
		// __trackMemoryUsage (memUsage);
		
	}
	
	
	@:noCompletion private override function __setSamplerState (state:SamplerState):Bool {
		
		if (super.__setSamplerState (state)) {
			
			var gl = __context.__gl;
			
			if (state.minFilter != gl.NEAREST && state.minFilter != gl.LINEAR && !__samplerState.mipmapGenerated) {
				
				gl.generateMipmap (gl.TEXTURE_2D);
				// GLUtils.CheckGLError ();
				
				__samplerState.mipmapGenerated = true;
				
			}
			
			if (state.maxAniso != 0.0) {
				
				gl.texParameterf (gl.TEXTURE_2D, Context3D.TEXTURE_MAX_ANISOTROPY_EXT, state.maxAniso);
				// GLUtils.CheckGLError ();
				
			}
			
			return true;
			
		}
		
		return false;
		
	}
	
	
	@:noCompletion private function __uploadCompressedTextureFromByteArray (data:ByteArray, byteArrayOffset:UInt):Void {
		
		var reader = new ATFReader (data, byteArrayOffset);
		var alpha = reader.readHeader (__width, __height, false);
		
		var context = __context;
		var gl = context.__gl;
		
		context.__bindTexture (__textureTarget, __textureID);
		GLUtils.CheckGLError ();
		
		var hasTexture = false;
		
		reader.readTextures (function (target, level, gpuFormat, width, height, blockLength, bytes:Bytes) {
			
			var format = TextureBase.__compressedTextureFormats.toTextureFormat (alpha, gpuFormat);
			if (format == 0) return;
			
			hasTexture = true;
			__format = format;
			__internalFormat = format;
			
			if (alpha && gpuFormat == 2) {
				
				var size = Std.int (blockLength / 2);
				
				gl.compressedTexImage2D (__textureTarget, level, __internalFormat, width, height, 0, new UInt8Array (bytes, 0, size));
				// GLUtils.CheckGLError ();
				
				var alphaTexture = new Texture (__context, __width, __height, Context3DTextureFormat.COMPRESSED, __optimizeForRenderToTexture, __streamingLevels);
				alphaTexture.__format = format;
				alphaTexture.__internalFormat = format;
				
				__context.__bindTexture (alphaTexture.__textureTarget, alphaTexture.__textureID);
				// GLUtils.CheckGLError ();
				
				gl.compressedTexImage2D (alphaTexture.__textureTarget, level, alphaTexture.__internalFormat, width, height, 0, new UInt8Array (bytes, 0, size));
				// GLUtils.CheckGLError ();
				
				__alphaTexture = alphaTexture;
				
			} else {
				
				gl.compressedTexImage2D (__textureTarget, level, __internalFormat, width, height, 0, new UInt8Array (bytes, 0, blockLength));
				// GLUtils.CheckGLError ();
				
			}
			
			// __trackCompressedMemoryUsage (blockLength);
			
		});
		
		if (!hasTexture) {
			
			var data = new UInt8Array (__width * __height * 4);
			gl.texImage2D (__textureTarget, 0, __internalFormat, __width, __height, 0, __format, gl.UNSIGNED_BYTE, data);
			// GLUtils.CheckGLError ();
			
		}
		
		context.__bindTexture (__textureTarget, null);
		// GLUtils.CheckGLError ();
		
	}
	
	
}


#else
typedef Texture = flash.display3D.textures.Texture;
#end