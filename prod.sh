#!/bin/bash

# Production environment manager

show_help() {
    echo "Usage: ./prod.sh [command]"
    echo ""
    echo "Environment commands:"
    echo "  start        - Start production environment (MySQL + Redis)"
    echo "  start-pg     - Start production with PostgreSQL + Redis"
    echo "  stop         - Stop all containers"
    echo "  restart      - Restart production environment"
    echo "  logs         - Show container logs"
    echo ""
    echo "Management commands:"
    echo "  build        - Build production images"
    echo "  deploy       - Build and start production"
    echo "  clean        - Stop and remove all containers/volumes"
    echo "  shell        - Open shell in app container"
    echo ""
    echo "Database commands:"
    echo "  backup       - Backup database"
    echo "  restore      - Restore database backup"
}

case "$1" in
    start)
        docker compose -f compose.prod.yaml --profile mysql --profile redis up -d
        ;;
    start-pg)
        docker compose -f compose.prod.yaml --profile postgres --profile redis up -d
        ;;
    stop)
        docker compose -f compose.prod.yaml down
        ;;
    restart)
        docker compose -f compose.prod.yaml down
        docker compose -f compose.prod.yaml --profile postgres --profile redis up -d
        ;;
    logs)
        docker compose -f compose.prod.yaml logs -f
        ;;
    build)
        docker compose -f compose.prod.yaml build --no-cache
        ;;
    deploy)
        docker compose -f compose.prod.yaml build --no-cache
        docker compose -f compose.prod.yaml --profile postgres --profile redis up -d
        ;;
    clean)
        docker compose -f compose.prod.yaml down -v
        ;;
    shell)
        docker compose -f compose.prod.yaml exec app bash
        ;;
    backup)
        echo "Creating database backup..."
        docker compose -f compose.prod.yaml exec postgres pg_dump -U ${DB_USERNAME:-laravel} ${DB_DATABASE:-laravel} > backup_$(date +%Y%m%d_%H%M%S).sql
        ;;
    restore)
        if [ -z "$2" ]; then
            echo "Usage: ./prod.sh restore <backup_file.sql>"
            exit 1
        fi
        echo "Restoring database from $2..."
        docker compose -f compose.prod.yaml exec -T postgres psql -U ${DB_USERNAME:-laravel} -d ${DB_DATABASE:-laravel} < "$2"
        ;;
    *)
        show_help
        ;;
esac