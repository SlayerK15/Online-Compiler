import subprocess
import os
from django.shortcuts import render

def compiler(request):
    code = request.POST.get('code', '')
    input_data = request.POST.get('input', '')
    output = ""
    selected_theme = request.POST.get('selected-theme', 'dracula')
    selected_language = request.POST.get('selected-language', 'python')

    if request.method == 'POST':
        try:
            if selected_language == 'python':
                with open("code.py", "w") as f:
                    f.write(code)
                process = subprocess.Popen(["python", "code.py"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                stdout, stderr = process.communicate(input=input_data.encode(), timeout=5)
                os.remove("code.py")
                output = stdout.decode() + stderr.decode()
            elif selected_language == 'javascript':
                with open("code.js", "w") as f:
                    f.write(code)
                process = subprocess.Popen(["node", "code.js"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                stdout, stderr = process.communicate(input=input_data.encode(), timeout=5)
                os.remove("code.js")
                output = stdout.decode() + stderr.decode()
            elif selected_language == 'cpp':
                with open("code.cpp", "w") as f:
                    f.write(code)
                process = subprocess.Popen(["g++", "code.cpp", "-o", "code"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                process.communicate()
                process = subprocess.Popen(["./code"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                stdout, stderr = process.communicate(input=input_data.encode(), timeout=5)
                os.remove("code.cpp")
                os.remove("code.exe")
                output = stdout.decode() + stderr.decode()
            elif selected_language == 'c':
                with open("code.cpp", "w") as f:
                    f.write(code)
                process = subprocess.Popen(["gcc", "code.cpp", "-o", "code"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                process.communicate()
                process = subprocess.Popen(["./code"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                stdout, stderr = process.communicate(input=input_data.encode(), timeout=5)
                os.remove("code.cpp")
                os.remove("code.exe")
                output = stdout.decode() + stderr.decode()
        except subprocess.TimeoutExpired:
            output = "The program exceeded the time limit of 5 seconds."
        except Exception as e:
            output = "An error occurred: " + str(e)

    return render(request, 'compiler/compiler.html', {
        'code': code,
        'input_data': input_data,
        'output': output,
        'selected_theme': selected_theme,
        'selected_language': selected_language
    })