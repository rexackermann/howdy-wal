#!/usr/bin/python3
import sys
import pam

def verify_password(user, password, service="login"):
    p = pam.pam()
    if p.authenticate(user, password, service=service):
        return True
    return False

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: pam_verify.py <user> <password> [service]")
        sys.exit(1)
    
    user = sys.argv[1]
    password = sys.argv[2]
    service = sys.argv[3] if len(sys.argv) > 3 else "login"
    
    if verify_password(user, password, service):
        sys.exit(0)
    else:
        sys.exit(1)
