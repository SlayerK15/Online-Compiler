import subprocess
import os
from django.shortcuts import render
import uuid

def compiler(request):
    code = request.POST.get('code', '')
    input_data = request.POST.get('input', '')
    output = ""
    selected_theme = request.POST.get('selected-theme', 'dracula')
    selected_language = request.POST.get('selected-language', 'python')

    if request.method == 'POST':
        try:
            # Create a unique filename for this compilation
            filename = f"code_{uuid.uuid4()}"
            
            if selected_language == 'python':
                with open(f"{filename}.py", "w") as f:
                    f.write(code)
                process = subprocess.Popen(["python", f"{filename}.py"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                stdout, stderr = process.communicate(input=input_data.encode(), timeout=5)
                os.remove(f"{filename}.py")
                output = stdout.decode() + stderr.decode()
            elif selected_language == 'javascript':
                with open(f"{filename}.js", "w") as f:
                    f.write(code)
                process = subprocess.Popen(["node", f"{filename}.js"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                stdout, stderr = process.communicate(input=input_data.encode(), timeout=5)
                os.remove(f"{filename}.js")
                output = stdout.decode() + stderr.decode()
            elif selected_language == 'java':
                # Ensure the class name matches the file name
                class_name = f"Code_{uuid.uuid4().hex}"
                with open(f"{class_name}.java", "w") as f:
                    # Wrap the user's code in a class with the matching name
                    f.write(f"public class {class_name} {{\n")
                    f.write("    public static void main(String[] args) {\n")
                    f.write(code)
                    f.write("\n    }\n}")
                
                # Compile
                compile_process = subprocess.Popen(["javac", f"{class_name}.java"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                compile_stdout, compile_stderr = compile_process.communicate(timeout=5)
                
                if compile_process.returncode == 0:
                    # Run
                    run_process = subprocess.Popen(["java", class_name], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                    stdout, stderr = run_process.communicate(input=input_data.encode(), timeout=5)
                    output = stdout.decode() + stderr.decode()
                else:
                    output = compile_stderr.decode()
                
                # Clean up
                os.remove(f"{class_name}.java")
                if os.path.exists(f"{class_name}.class"):
                    os.remove(f"{class_name}.class")
            elif selected_language in ['c', 'cpp']:
                extension = 'c' if selected_language == 'c' else 'cpp'
                compiler = 'gcc' if selected_language == 'c' else 'g++'
                with open(f"{filename}.{extension}", "w") as f:
                    f.write(code)
                compile_process = subprocess.Popen([compiler, f"{filename}.{extension}", "-o", filename], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                compile_stdout, compile_stderr = compile_process.communicate(timeout=5)
                if compile_process.returncode == 0:
                    run_process = subprocess.Popen([f"./{filename}"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                    stdout, stderr = run_process.communicate(input=input_data.encode(), timeout=5)
                    output = stdout.decode() + stderr.decode()
                else:
                    output = compile_stderr.decode()
                os.remove(f"{filename}.{extension}")
                if os.path.exists(filename):
                    os.remove(filename)
        except subprocess.TimeoutExpired:
            output = "The program exceeded the time limit of 5 seconds."
        except Exception as e:
            output = f"An error occurred: {str(e)}"

    return render(request, 'compiler/compiler.html', {
        'code': code,
        'input_data': input_data,
        'output': output,
        'selected_theme': selected_theme,
        'selected_language': selected_language
    })