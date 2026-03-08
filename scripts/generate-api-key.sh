#!/bin/bash
###############################################################################
# generate-api-key.sh
#
# Gera uma SERVICE_API_KEY via auth-service e atualiza automaticamente
# o secret do evaluation-service.
###############################################################################
set -e

echo "============================================"
echo "  ToggleMaster - Gerar SERVICE_API_KEY"
echo "============================================ "
echo ""

# Verificar se auth-service esta rodando
echo ">>> Verificando se auth-service esta Running..."
AUTH_STATUS=$(kubectl get pods -n togglemaster -l app=auth-service -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NotFound")

if [ "$AUTH_STATUS" != "Running" ]; then
  echo "ERRO: auth-service nao esta Running (status: $AUTH_STATUS)"
  exit 1
fi
echo "  [OK] auth-service esta Running"

# Liberar porta 8001 se estiver ocupada
if lsof -i :8001 > /dev/null 2>&1; then
  echo "  AVISO: Porta 8001 em uso. Liberando..."
  kill $(lsof -t -i :8001) 2>/dev/null || true
  sleep 2
fi

# Port-forward em background
echo ">>> Abrindo port-forward para auth-service..."
kubectl port-forward svc/auth-service 8001:8001 -n togglemaster > /dev/null 2>&1 &
PF_PID=$!
sleep 3

# Cleanup ao sair
cleanup() {
  kill $PF_PID 2>/dev/null || true
}
trap cleanup EXIT

# Obter MASTER_KEY (Limpando quebras de linha do base64)
echo ">>> Obtendo MASTER_KEY do secret..."
MASTER_KEY=$(kubectl get secret auth-service-secret -n togglemaster \
  -o jsonpath='{.data.MASTER_KEY}' | base64 -d | tr -d '\n' | tr -d '\r')

echo "  [OK] MASTER_KEY obtida."

# Gerar API key e limpar a saida
echo ">>> Gerando API key via auth-service..."
RESPONSE=$(curl -s -X POST http://localhost:8001/admin/keys \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $MASTER_KEY" \
  -d '{"name": "evaluation-service"}')

# Extração limpa da chave
API_KEY=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('key',''))" 2>/dev/null | tr -d '\n' | tr -d '\r')

if [ -z "$API_KEY" ]; then
  echo "ERRO: Nao foi possivel gerar a API key. Resposta: $RESPONSE"
  exit 1
fi
echo "  [OK] API Key gerada com sucesso."

# --- CORREÇÃO AQUI ---
# Atualizar usando stringData para evitar erros de escape/JSON
echo ">>> Atualizando evaluation-service-secret..."
kubectl patch secret evaluation-service-secret -n togglemaster \
  --type='merge' \
  -p "{\"stringData\":{\"SERVICE_API_KEY\":\"$API_KEY\"}}"

echo "  [OK] Secret atualizado via stringData."
echo ""

# Reiniciar pods
echo ">>> Reiniciando pods do evaluation-service..."
kubectl rollout restart deployment/evaluation-service -n togglemaster
kubectl rollout status deployment/evaluation-service -n togglemaster --timeout=120s

echo "============================================"
echo "  SETUP FINALIZADO COM SUCESSO!"
echo "============================================"