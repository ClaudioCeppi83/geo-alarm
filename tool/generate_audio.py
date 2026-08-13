import os
import wave
import struct
import math

def generate_synthetic_audio(output_path):
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    sample_rate = 44100
    duration = 2.0  # seconds
    frequency = 880.0  # A5 pitch
    
    num_samples = int(sample_rate * duration)
    
    with wave.open(output_path, 'wb') as wav_file:
        wav_file.setnchannels(1)  # Mono
        wav_file.setsampwidth(2)  # 16-bit
        wav_file.setframerate(sample_rate)
        
        frames = []
        for i in range(num_samples):
            t = float(i) / sample_rate
            # Beep pattern: 0.2s sound, 0.1s silence
            cycle = t % 0.3
            if cycle < 0.2:
                value = int(32767.0 * 0.5 * math.sin(2.0 * math.pi * frequency * t))
            else:
                value = 0
            frames.append(struct.pack('<h', value))
            
        wav_file.writeframes(b''.join(frames))
    print(f"Generated synthetic audio at {output_path}")

if __name__ == '__main__':
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    target = os.path.join(base_dir, 'assets', 'audio', 'alarm.mp3')
    generate_synthetic_audio(target)
