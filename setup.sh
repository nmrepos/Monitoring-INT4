#!/bin/bash

# Setup script for GitHub Codespace
echo "🚀 Setting up Monitoring Infrastructure with k8s-infra..."

# Check if we're in a codespace
if [ -n "$CODESPACE_NAME" ]; then
    echo "✅ Running in GitHub Codespace: $CODESPACE_NAME"
else
    echo "ℹ️  Not running in GitHub Codespace"
fi

# Install Python dependencies
echo "📦 Installing Python dependencies..."
pip install -r requirements.txt

# Install Ansible collections
echo "🔧 Installing Ansible collections..."
ansible-galaxy collection install kubernetes.core
ansible-galaxy collection install community.docker

# Initialize git submodules
echo "📋 Initializing git submodules..."
git submodule update --init --recursive

# Apply SigNoz patch
echo "🔧 Applying SigNoz patch..."
if [ -f "signoz/patch.diff" ]; then
    cd signoz
    patch -p1 < patch.diff || echo "⚠️  Patch may already be applied"
    cd ..
fi

# Set environment variables for k8s setup
export K8S=k3d

echo "✅ Setup completed!"
echo ""
echo "🎯 Next steps:"
echo "1. Run: ansible-playbook up.yml"
echo "2. Wait for all services to start (this may take several minutes)"
echo "3. Access SigNoz at http://localhost:3301"
echo "4. Access rolldice app: kubectl port-forward service/rolldice-otel-service 8080:80"
echo "5. Open http://localhost:8080 to test the rolldice application"
echo ""
echo "📊 To monitor telemetry:"
echo "- Check SigNoz dashboard for 'rolldice-otel' service"
echo "- Telemetry is automatically generated every minute"
echo ""
echo "🛑 To cleanup: ansible-playbook down.yml"
