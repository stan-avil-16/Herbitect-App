from flask import Flask, request, jsonify
from flask_mail import Mail, Message
from flask_cors import CORS
import random
import os
import firebase_admin
from firebase_admin import credentials, auth, firestore
from datetime import datetime, timezone, timedelta

app = Flask(__name__)
CORS(app)

# Configure your email here
app.config['MAIL_SERVER'] = 'smtp.gmail.com'
app.config['MAIL_PORT'] = 587
app.config['MAIL_USE_TLS'] = True
app.config['MAIL_USERNAME'] = os.environ.get('MAIL_USERNAME')
app.config['MAIL_PASSWORD'] = os.environ.get('MAIL_PASSWORD')

mail = Mail(app)

# Initialize Firebase Admin SDK
db = None
try:
    # This will use the GOOGLE_APPLICATION_CREDENTIALS environment variable
    cred = credentials.ApplicationDefault()
    firebase_admin.initialize_app(cred)
    db = firestore.client()
    print("Firebase Admin SDK initialized successfully.")
except Exception as e:
    print(f"Failed to initialize Firebase Admin SDK: {e}")

def generate_otp():
    return str(random.randint(100000, 999999))

@app.route('/check-email', methods=['POST'])
def check_email():
    data = request.get_json()
    email = data.get('email')
    if not email:
        return jsonify({'error': 'Email is required'}), 400
    
    try:
        auth.get_user_by_email(email)
        # User exists
        return jsonify({'exists': True})
    except auth.UserNotFoundError:
        # User does not exist
        return jsonify({'exists': False})
    except Exception as e:
        print(f"Error checking email: {e}")
        return jsonify({'error': 'An internal server error occurred'}), 500

@app.route('/send-otp', methods=['POST'])
def send_otp():
    data = request.get_json()
    email = data.get('email')
    if not email or not db:
        return jsonify({'error': 'Email is required and database must be initialized.'}), 400

    otp = generate_otp()

    try:
        # Store OTP in Firestore with a timestamp
        doc_ref = db.collection('otps').document(email)
        doc_ref.set({
            'otp': otp,
            'timestamp': firestore.SERVER_TIMESTAMP
        })

        msg = Message('Your OTP for HerbiTect', sender=os.environ.get('MAIL_USERNAME'), recipients=[email])
        msg.body = f'Your OTP is: {otp}. It is valid for 10 minutes.'
        mail.send(msg)
        return jsonify({'success': True, 'message': 'OTP sent successfully.'})
    except Exception as e:
        print(f"Error sending OTP: {e}")
        return jsonify({'error': 'Failed to send OTP'}), 500

@app.route('/verify-otp', methods=['POST'])
def verify_otp():
    data = request.get_json()
    email = data.get('email')
    user_otp = data.get('otp')

    if not all([email, user_otp, db]):
        return jsonify({'error': 'Email and OTP are required and database must be initialized.'}), 400

    try:
        doc_ref = db.collection('otps').document(email)
        doc = doc_ref.get()

        if not doc.exists:
            return jsonify({'success': False, 'error': 'OTP not found. It may have expired.'})

        stored_data = doc.to_dict()
        stored_otp = stored_data.get('otp')
        stored_timestamp = stored_data.get('timestamp')

        # OTPs are valid for 10 minutes
        if datetime.now(timezone.utc) - stored_timestamp > timedelta(minutes=10):
            doc_ref.delete() # Clean up expired OTP
            return jsonify({'success': False, 'error': 'OTP has expired.'})

        if user_otp == stored_otp:
            doc_ref.delete()  # Delete OTP after successful verification
            return jsonify({'success': True})
        else:
            return jsonify({'success': False, 'error': 'Invalid OTP.'})

    except Exception as e:
        print(f"Error verifying OTP: {e}")
        return jsonify({'success': False, 'error': 'An internal server error occurred.'})

@app.route('/reset-password', methods=['POST'])
def reset_password():
    data = request.get_json()
    email = data.get('email')
    otp = data.get('otp')
    new_password = data.get('new_password')
    if not all([email, otp, new_password, db]):
        return jsonify({'success': False, 'error': 'Email, OTP, and new password are required.'}), 400
    try:
        # 1. Verify OTP (must exist and match)
        doc_ref = db.collection('otps').document(email)
        doc = doc_ref.get()
        if not doc.exists:
            return jsonify({'success': False, 'error': 'OTP not found. It may have expired.'})
        stored_data = doc.to_dict()
        stored_otp = stored_data.get('otp')
        stored_timestamp = stored_data.get('timestamp')
        if datetime.now(timezone.utc) - stored_timestamp > timedelta(minutes=10):
            doc_ref.delete()
            return jsonify({'success': False, 'error': 'OTP has expired.'})
        if otp != stored_otp:
            return jsonify({'success': False, 'error': 'Invalid OTP.'})
        # 2. Update password in Firebase Auth
        user = auth.get_user_by_email(email)
        auth.update_user(user.uid, password=new_password)
        doc_ref.delete()  # Remove OTP after use
        return jsonify({'success': True, 'message': 'Password updated successfully.'})
    except Exception as e:
        print(f"Error resetting password: {e}")
        return jsonify({'success': False, 'error': 'Failed to reset password.'}), 500

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=int(os.environ.get('PORT', 10000))) 