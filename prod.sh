#!/bin/bash

# Production environment manager

show_help() {
    echo "Usage: ./prod.sh [command] [flags]"
    echo ""
    echo "Environment commands:"
    echo "  start [--mysql] [--postgres] [--redis] [--no-recreate] - Start production environment"
    echo "    Examples:"
    echo "      ./prod.sh start                       # PostgreSQL + Redis (default)"
    echo "      ./prod.sh start --mysql --redis       # MySQL + Redis"
    echo "      ./prod.sh start --postgres --redis    # PostgreSQL + Redis"
    echo "      ./prod.sh start --mysql --postgres    # Both databases"
    echo "      ./prod.sh start --postgres            # PostgreSQL only"
    echo "      ./prod.sh start --redis               # Redis only"
    echo "      ./prod.sh start --no-recreate         # Don't recreate containers"
    echo ""
    echo "  stop [-v]     - Stop containers (-v removes volumes)"
    echo "  restart       - Restart production environment"
    echo "  logs          - Show container logs"
    echo ""
    echo "Management commands:"
    echo "  build         - Build production images"
    echo "  deploy        - Build and start production"
    echo "  clean         - Stop and remove all containers/volumes"
    echo "  shell         - Open shell in app container"
    echo ""
    echo "Database commands:"
    echo "  backup        - Backup database"
    echo "  restore       - Restore database backup"
}

parse_start_flags() {
    local profiles=""
    local compose_flags=""

    # Start with no services (explicit opt-in)
    local use_mysql=false
    local use_postgres=false
    local use_redis=false

    shift # Remove 'start' command

    # If no flags provided, default to PostgreSQL + Redis for production
    if [[ $# -eq 0 ]]; then
        use_postgres=true
        use_redis=true
    fi

    while [[ $# -gt 0 ]]; do
        case $1 in
            --mysql)
                use_mysql=true
                shift
                ;;
            --postgres)
                use_postgres=true
                shift
                ;;
            --redis)
                use_redis=true
                shift
                ;;
            --no-recreate)
                compose_flags="$compose_flags --no-recreate"
                shift
                ;;
            *)
                echo "Unknown flag: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # Build profiles
    if [[ "$use_mysql" == true ]]; then
        profiles="$profiles --profile mysql"
    fi
    if [[ "$use_postgres" == true ]]; then
        profiles="$profiles --profile postgres"
    fi
    if [[ "$use_redis" == true ]]; then
        profiles="$profiles --profile redis"
    fi

    echo "$profiles$compose_flags"
}

case "$1" in
    start)
        flags=$(parse_start_flags "$@")
        docker compose -f compose.prod.yaml $flags up -d
        ;;
    stop)
        if [[ "$2" == "-v" ]]; then
            docker compose -f compose.prod.yaml down -v
        else
            docker compose -f compose.prod.yaml down
        fi
        ;;
    restart)
        docker compose -f compose.prod.yaml down
        flags=$(parse_start_flags "start" "--postgres" "--redis")
        docker compose -f compose.prod.yaml $flags up -d
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