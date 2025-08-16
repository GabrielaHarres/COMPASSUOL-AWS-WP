# COMPASSUOL-AWS-WP

# WordPress em Alta Disponibilidade (AWS) — EC2 + ALB + EFS + RDS 🚀

Este projeto provisiona uma instância WordPress em EC2 usando Docker/Compose, com arquivos persistentes no Amazon EFS e banco no Amazon RDS (MySQL/MariaDB). A ideia é que múltiplas EC2 (em ASG) possam compartilhar o mesmo wp-content via EFS e falar com o mesmo RDS atrás de um Application Load Balancer.

---

### Arquitetura (resumo) 🌐

- ALB nas subnets públicas → distribui para EC2 nas subnets privadas.
- EC2 (ASG + LT) executa contêiner WordPress + phpMyAdmin (opcional).
- EFS monta o diretório wp-content (uploads, temas, plugins) de forma compartilhada.
- RDS armazena o banco do WordPress.

---

### Pré‑requisitos 🛠️

1. VPC com 2 AZs, subnets públicas (ALB) e privadas (EC2/RDS).
2. **Security Groups**:
   - ALB: permitir 80 (HTTP) do mundo.
   - EC2: permitir 80 somente do SG do ALB.
   - RDS: permitir 3306 somente do SG das EC2.
   - EFS: permitir 2049 (NFS) do SG das EC2.
3. RDS criado (DB, usuário, senha) e endpoint copiado.
4. EFS criado (mesma VPC/AZs) com SG adequado.
5. AMI: Amazon Linux 2/2023 funciona bem.

---

### Como usar 🚀

1. Edite no `script.sh`:
   - EFS_ID, DB_ENDPOINT, DB_NAME, DB_USER, DB_PASSWORD.
   
2. Cole o conteúdo do `script.sh` no campo **User data** do seu Launch Template:
   - EC2 → Launch Templates → Create template → Advanced details → User data.

3. Dica: marque o template para as subnets privadas, e anexe um IAM Role básico (se houver).

4. Crie um **Auto Scaling Group** a partir do Launch Template e conecte-o ao Target Group do seu ALB.

5. No **ALB Health Check**, use o caminho `/wp-login.php` (responde rápido).

6. Abra no navegador o DNS do ALB → finalize a instalação do WordPress.

---

### Por que funciona em alta disponibilidade? 🏆

- Qualquer instância EC2 nova (ASG) monta o mesmo EFS em `/mnt/efs/wp-content`.
- Todas apontam para o mesmo banco no RDS.
- O ALB distribui tráfego apenas para instâncias saudáveis.

---

### Comandos úteis (SSH na EC2) 🖥️

- Ver containers:

  ```bash
  docker ps
´´´ 

### Logs do WordPress:


docker logs -f $(docker ps --format '{{.Names}}' | grep wordpress)


### Atualizar a pilha após editar arquivos:


cd /opt/wordpress && docker-compose pull && docker-compose up -d



### Limpeza (evitar custo!) 💰

Apague o ASG, Launch Template, ALB/Target Group, EFS e RDS quando terminar.

Remova a VPC se tiver criado uma dedicada pro lab.
