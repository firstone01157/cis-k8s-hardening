import subprocess
import os
import json

# กำหนด Path ที่จะไปหา Script (ใน Container)
BASE_DIR = "/app/cis_scripts"

results = {"pass": [], "fail": []}

def run_checks():
    # เดินหาไฟล์ _audit.sh ทั้งหมด
    for root, dirs, files in os.walk(BASE_DIR):
        for file in files:
            if file.endswith("_audit.sh"):
                full_path = os.path.join(root, file)
                # รัน Script
                result = subprocess.run([full_path], capture_output=True, text=True)
                
                if result.returncode == 0:
                    results["pass"].append({"file": file, "output": result.stdout.strip()})
                    print(f"✅ PASS: {file}")
                else:
                    results["fail"].append({"file": file, "output": result.stdout.strip()})
                    print(f"❌ FAIL: {file}")

    # Save Report
    with open("/app/report.json", "w") as f:
        json.dump(results, f, indent=4)

if __name__ == "__main__":
    run_checks()import subprocess
import os
import json

# กำหนด Path ที่จะไปหา Script (ใน Container)
BASE_DIR = "/app/cis_scripts"

results = {"pass": [], "fail": []}

def run_checks():
    # เดินหาไฟล์ _audit.sh ทั้งหมด
    for root, dirs, files in os.walk(BASE_DIR):
        for file in files:
            if file.endswith("_audit.sh"):
                full_path = os.path.join(root, file)
                # รัน Script
                result = subprocess.run([full_path], capture_output=True, text=True)
                
                if result.returncode == 0:
                    results["pass"].append({"file": file, "output": result.stdout.strip()})
                    print(f"✅ PASS: {file}")
                else:
                    results["fail"].append({"file": file, "output": result.stdout.strip()})
                    print(f"❌ FAIL: {file}")

    # Save Report
    with open("/app/report.json", "w") as f:
        json.dump(results, f, indent=4)

if __name__ == "__main__":
    run_checks()