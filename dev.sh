#!/bin/bash

# Development environment manager

show_help() {
    echo "Usage: ./dev.sh [command]"
    echo ""
    echo "Environment commands:"
    echo "  start        - Start development environment (MySQL + Redis)"
    echo "  start-pg     - Start development with PostgreSQL + Redis"
    echo "  stop         - Stop all containers"
    echo "  restart      - Restart development environment"
    echo "  logs         - Show container logs"
    echo ""
    echo "Development commands:"
    echo "  composer     - Run composer install"
    echo "  artisan [cmd] - Run artisan commands (e.g., ./dev.sh artisan migrate)"
    echo "  npm [cmd]    - Run npm commands (e.g., ./dev.sh npm 'run dev')"
    echo ""
    echo "Database commands:"
    echo "  mysql        - Connect to MySQL"
    echo "  postgres     - Connect to PostgreSQL"
    echo "  redis        - Connect to Redis"
    echo ""
    echo "Utility commands:"
    echo "  build        - Rebuild containers"
    echo "  clean        - Stop and remove all containers/volumes"
    echo "  shell        - Open shell in app container"
}

case "$1" in
    start)
        docker compose -f compose.dev.yaml up -d
        ;;
    start-pg)
        docker compose -f compose.dev.yaml --profile postgres up -d
        ;;
    stop)
        docker compose -f compose.dev.yaml down
        ;;
    restart)
        docker compose -f compose.dev.yaml down
        docker compose -f compose.dev.yaml up -d
        ;;
    logs)
        docker compose -f compose.dev.yaml logs -f
        ;;
    composer)
        docker compose -f compose.dev.yaml exec app composer install
        ;;
    artisan)
        shift
        docker compose -f compose.dev.yaml exec app php artisan "$@"
        ;;
    npm)
        shift
        docker compose -f compose.dev.yaml exec app npm "$@"
        ;;
    mysql)
        docker compose -f compose.dev.yaml exec mysql mysql -u root -p
        ;;
    postgres)
        docker compose -f compose.dev.yaml exec postgres psql -U ${DB_USERNAME:-laravel} -d ${DB_DATABASE:-laravel}
        ;;
    redis)
        docker compose -f compose.dev.yaml exec redis redis-cli
        ;;
    build)
        docker compose -f compose.dev.yaml build --no-cache
        ;;
    clean)
        docker compose -f compose.dev.yaml down -v
        ;;
    shell)
        docker compose -f compose.dev.yaml exec app bash
        ;;
    *)
        show_help
        ;;
esac