package;

import haxe.io.Path;
import sys.FileSystem;
import java.StdTypes.Int8;
import java.NativeArray;
import java.io.FileOutputStream;
import java.io.File;
import java.nio.file.Files;
import org.objectweb.asm.ClassReader;
import org.objectweb.asm.ClassWriter;
import org.objectweb.asm.ClassVisitor;
import org.objectweb.asm.MethodVisitor;
import org.objectweb.asm.Opcodes;
import java.Lib.println;

using StringTools;

/**
 * HOW TO USE:
 *
 * 1) Unpack OpenJDK standard lib bytecode (.class files) into some folder. For example "jar_content";
 *   a) If JDK <= 8: unzip rt.jar
 *   b) If JDK >= 9: bin/jimage lib/modules
 * 2) Run `java -jar Main.jar jar_content`;
 * 3) Pick up generated `hxjava-std.jar`.
 */
final class Main {
	
	static function main():Void {

		final args:Array<String> = Sys.args();
		if (args.length > 0) {
			final root = Path.addTrailingSlash(args[0]);
			final out = Path.join([root, '../interim']);
			
			(function process(dir:String) {
				if (FileSystem.exists(dir)) {
					for (file in FileSystem.readDirectory(dir)) {
						final path = Path.join([dir, file]);
						if (!FileSystem.isDirectory(path)) {
							if (path.endsWith(".class") && Path.withoutDirectory(path) != 'module-info.class') {
								println('Process $path... ');
								final obj:NativeArray<Int8> = Files.readAllBytes(new File(path).toPath());
								final reader = new ClassReader(obj);
								final writer = new ClassWriter(ClassWriter.COMPUTE_FRAMES | ClassWriter.COMPUTE_MAXS);
								final visitor = new CustomClassVisitor(writer);

								reader.accept(visitor, 0);

								final parts = path.substr(root.length).split('/');
								final dst = Path.join([out].concat(parts[0].contains('.') ? parts.slice(1) : parts));
								if(!FileSystem.exists(Path.directory(dst))) 
									FileSystem.createDirectory(Path.directory(dst));
								final stream = new FileOutputStream(dst);
								stream.write(writer.toByteArray());
							}
						} else {
							process(Path.addTrailingSlash(path));
						}
					}
				} else {
					println('Wrong path. $dir is not exists');
				}
			})(root);
			
			println("\nPacking jar...\n");
			if (Sys.command('jar', ["cvf", "hxjava-std.jar", "-C", out, "."]) == 0) {
				println("\nDone!\n");
			} else {
				println("Oops, something went wrong.");
			}
		}
	}
}

@:nativeGen
class CustomClassVisitor extends ClassVisitor {

	public function new(visitor:ClassVisitor) {
		super(Opcodes.ASM7, visitor);
	}

	@:overload
	override function visit(version:Int, access:Int, name:String, signature:String, superName:String, interfaces:NativeArray<String>):Void {
		cv.visit(version, access, name, signature, superName, interfaces);
	}

	/**
	 * Starts the visit of the method's code, if any (i.e. non abstract method).
	 */
	@:overload
	override function visitMethod(access:Int, name:String, desc:String, signature:String, exceptions:NativeArray<String>):MethodVisitor {
		final mv:MethodVisitor = cv.visitMethod(access, name, desc, signature, exceptions);
		if (mv != null) {
			return new CustomMethodVisitor(mv);
		}
		return mv;
	}
}

@:nativeGen
class CustomMethodVisitor extends MethodVisitor {
	final target:MethodVisitor;

	public function new(target:MethodVisitor) {
		super(Opcodes.ASM7, null);
		this.target = target;
	}

	@:overload
	override function visitCode() {
		target.visitCode();
		target.visitMaxs(0, 0);
		target.visitEnd();
	}
}
