#!/bin/bash
# PaperBanana Quick Install
# Usage: curl -sL https://raw.githubusercontent.com/stuinfla/paperbanana/main/install.sh | bash
set -e
echo "Installing PaperBanana Storytelling Pipeline..."

# Check Python
python3 --version || { echo "Python 3.10+ required. Install from python.org"; exit 1; }

# Clone
git clone https://github.com/stuinfla/paperbanana.git ~/paperbanana 2>/dev/null || { echo "Already cloned at ~/paperbanana"; cd ~/paperbanana && git pull; }
cd ~/paperbanana

# Setup venv + deps
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt -q

# Prompt for API key
if [ -z "$GOOGLE_API_KEY" ]; then
  echo ""
  echo "You need a Google Gemini API key (free at https://aistudio.google.com/apikey)"
  read -p "Enter your GOOGLE_API_KEY: " key
  echo "export GOOGLE_API_KEY=\"$key\"" >> ~/.zshrc 2>/dev/null || echo "export GOOGLE_API_KEY=\"$key\"" >> ~/.bashrc
  export GOOGLE_API_KEY="$key"
fi

echo ""
echo "Done! Try:"
echo "  cd ~/paperbanana"
echo "  .venv/bin/python cli_generate.py --content 'A neural network with 3 layers' --caption 'Figure 1: Neural Architecture' --output diagram.png --mode demo_full"
