# Copilot Instructions: [NOME DO PROJETO]

<!-- 
  Este arquivo é o "onboarding do agente" — lido no início de cada sessão.
  Preencha todas as seções marcadas com [DEFINIR: ...].
  Remova os comentários <!-- --> após preencher.

Dica: rode /setup para gerar este arquivo automaticamente.
-->

## Project Overview

[DEFINIR: 2-3 frases descrevendo o que o projeto faz, sua linguagem principal e contexto de negócio]

Exemplo: _"Serviço Node.js para gestão de pedidos do e-commerce XYZ. Expõe API REST consumida pelo frontend React e por integrações B2B via webhook."_

---

## Architecture

### Core Stack

- **Language/Runtime**: [DEFINIR: ex. Node.js 22, Java 21, Go 1.22, Python 3.12]
- **Framework**: [DEFINIR: ex. Spring Boot 3.2, NestJS 11, Gin, FastAPI, Next.js 14]
- **Database**: [DEFINIR: ex. PostgreSQL via JPA/Hibernate, MySQL via GORM, Oracle via Sequelize, MongoDB via Mongoose]
- **Auth**: [DEFINIR: ex. JWT RS256, OAuth2 PKCE, API Key, Session]
- **Observability**: [DEFINIR: ex. OpenTelemetry, Prometheus, Datadog, CloudWatch]
- **Testing**: [DEFINIR: ex. JUnit 5 + Mockito, Jest + ts-jest, pytest, Go testing]

### Module/Package Structure

```
[DEFINIR: Cole aqui a estrutura principal de pastas do projeto, ex:]

src/
├── controllers/    # Entry points HTTP
├── services/       # Business logic
├── repositories/   # Data access
├── models/         # Domain entities
└── config/         # Configuration
```

---

## Key Conventions

### Exception Handling

[DEFINIR: Como o projeto trata erros. Exemplos:]

**Spring Boot:**

```java
// Exceções de negócio estendem RuntimeException com código HTTP
throw new BusinessException("MSG-001", "Valor inválido para campo X");
// @ControllerAdvice formata para { "code": "MSG-001", "message": "..." }
```

**Go:**

```go
// Errors como valores, wrapping com fmt.Errorf
if err != nil {
    return fmt.Errorf("criar pedido: %w", err)
}
```

### Authentication Pattern

[DEFINIR: Como a autenticação funciona no projeto. Ex:]

- JWT validado via middleware/guard em todas as rotas
- Header `Authorization: Bearer <token>`
- Payload contém: `sub`, `roles`, `exp`

### Logging

[DEFINIR: Biblioteca e padrão de logs. Ex:]

```java
private static final Logger log = LoggerFactory.getLogger(MyService.class);
log.info("Operação realizada: {}", resultado);
// NUNCA logar: tokens, senhas, dados pessoais (LGPD)
```

### Environment Variables

[DEFINIR: Variáveis de ambiente obrigatórias e como acessá-las. Ex:]

| Variável           | Descrição                  | Exemplo                                 |
| ------------------ | -------------------------- | --------------------------------------- |
| `DATABASE_URL`     | Connection string do banco | `jdbc:postgresql://localhost:5432/mydb` |
| `JWT_SECRET`       | Chave para validação JWT   | `***`                                   |
| `EXTERNAL_API_URL` | URL da API externa         | `https://api.example.com`               |

### Database / Repository Pattern

[DEFINIR: Padrões de acesso a dados. Ex:]

```java
// JPA: sempre usar projections para queries de listagem
@Query("SELECT new com.example.dto.PedidoSummary(p.id, p.status) FROM Pedido p")
List<PedidoSummary> findAllSummaries();
```

---

## Padrões Obrigatórios

Checklist derivado das seções acima — vale para toda implementação ou correção de código, não só a fase em que o padrão foi introduzido. Verificar antes de considerar qualquer fase/correção concluída:

- **Exception handling**: usar tipos do projeto, não exceções genéricas
- **Logging**: usar o logger do projeto, nunca `console.log`/`System.out.println` em produção
- **Variáveis de ambiente**: sempre via função/método helper do projeto — nunca `process.env.X` ou `System.getenv()` diretamente
- **Segurança**: nunca logar tokens, senhas ou dados pessoais

---

## Arquivos Protegidos

`.github/prompts/*.md` e este arquivo (`copilot-instructions.md`) só podem ser alterados por `/setup` e `/lesson`. Nenhum outro comando (`/code`, `/fix-review`, etc.) deve editá-los, mesmo incidentalmente — mudanças nesses arquivos alteram o comportamento de todo o workflow e precisam passar pelo mecanismo de revisão deliberada que `/setup` e `/lesson` representam.

---

## Development Commands

<!-- IMPORTANTE: Preencha os comandos exatos do projeto — /setup usa esta seção para preencher .github/scripts/validate.sh (test/lint/build), consumido por /code, /test e /rc -->

```bash
# Instalar dependências
[DEFINIR: ex. npm install | mvn install | go mod download | pip install -r requirements.txt]

# Executar em desenvolvimento
[DEFINIR: ex. npm run start:dev | mvn spring-boot:run | go run ./cmd/server]

# Executar testes
[DEFINIR: ex. npm test | mvn test | go test ./... | pytest]

# Cobertura de testes
[DEFINIR: ex. npm run test:cov | mvn jacoco:report | go test -cover ./...]

# Lint / formatação
[DEFINIR: ex. npm run lint | mvn checkstyle:check | golangci-lint run | ruff check .]

# Build
[DEFINIR: ex. npm run build | mvn package | go build ./... | docker build .]
```

**Caminho do relatório de cobertura:** `[DEFINIR: ex. coverage/lcov-report/index.html | target/site/jacoco/index.html | coverage.html]`

---

## Integration Points

[DEFINIR: APIs externas, filas, sistemas legados que o projeto integra. Ex:]

### API de Pagamentos (Stripe)

- Endpoint base: `https://api.stripe.com/v1`
- Autenticação: API Key via `Authorization: Bearer sk_...`
- Env: `STRIPE_SECRET_KEY`
- Criar charge: `POST /charges`

### Fila de Eventos (RabbitMQ)

- Fila: `orders.created`
- Formato: JSON com `orderId`, `customerId`, `amount`
- Consumer em `src/consumers/order.consumer.ts`

---

## Common Pitfalls

<!-- Adicione aqui erros recorrentes via /lesson -->

- [DEFINIR: Armadilha 1 — ex. "Nunca retornar entities JPA diretamente nas responses — usar DTOs para evitar lazy loading exceptions"]
- [DEFINIR: Armadilha 2 — ex. "Sempre fechar conexões com banco em blocos finally ou usar try-with-resources"]
- [DEFINIR: Armadilha 3 — ex. "Datas: sempre usar UTC no banco e converter para timezone do usuário na camada de apresentação"]

---

## Testing Conventions

[DEFINIR: Padrões de testes do projeto. Ex:]

```typescript
// Estrutura padrão de teste unitário
describe("OrderService", () => {
  let service: OrderService;
  let mockRepository: jest.Mocked<OrderRepository>;

  beforeEach(async () => {
    const module = await Test.createTestingModule({
      providers: [
        OrderService,
        { provide: OrderRepository, useValue: { findById: jest.fn() } },
      ],
    }).compile();
    service = module.get(OrderService);
    mockRepository = module.get(OrderRepository);
  });

  it("deve lançar exceção quando pedido não encontrado", async () => {
    mockRepository.findById.mockResolvedValue(null);
    await expect(service.getOrder(999)).rejects.toThrow(OrderNotFoundException);
  });
});
```

**Meta de cobertura:** [DEFINIR: ex. 80%] de statements

---

## Release Workflow

[DEFINIR: Estratégia de versionamento e branches. Ex:]

- **Branch principal**: `main` (produção)
- **Branch de integração**: `develop` (staging)
- **Features**: `feature/nome-descritivo` a partir de `develop`
- **Versionamento**: Semver (`MAJOR.MINOR.PATCH`) — develop usa sufixo `-rc.N`
- **Arquivos de versão**: [DEFINIR: ex. package.json + package-lock.json | pyproject.toml | pom.xml | Cargo.toml]
- **CHANGELOG no desenvolvimento**: registrar cada entrega em seção versionada RC no topo, usando `Unreleased` no lugar da data (ex.: `## [2.3.0-rc.2] - Unreleased`)
