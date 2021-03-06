defmodule Adminable.AdminController do
  @moduledoc false

  use Phoenix.Controller, namespace: Adminable
  import Plug.Conn

  def dashboard(conn, _params) do
    schemas = Map.keys(conn.private.adminable_schemas)

    opts = [
      schemas: schemas
    ]

    conn
    |> put_layout(conn.private.adminable_layout)
    |> put_view(conn.private.adminable_view_module)
    |> render("dashboard.html", opts)
  end

  def index(conn, %{"schema" => schema} = params) do
    schema_module = conn.private.adminable_schemas[schema]

    paginate_config = [
      page_size: 20,
      page: Map.get(params, "page", 1),
      module: conn.private.adminable_repo
    ]

    page = Scrivener.paginate(schema_module, paginate_config)

    opts = [
      schema_module: schema_module,
      schema: schema,
      schemas: page.entries,
      page_number: page.page_number,
      page_size: page.page_size,
      total_pages: page.total_pages,
      total_entries: page.total_entries
    ]

    conn
    |> put_layout(conn.private.adminable_layout)
    |> put_view(conn.private.adminable_view_module)
    |> render("index.html", opts)
  end

  def new(conn, %{"schema" => schema}) do
    schema_module = conn.private.adminable_schemas[schema]

    model = struct(schema_module)

    opts = [
      changeset: schema_module.create_changeset(model, %{}),
      schema_module: schema_module,
      schema: schema
    ]

    conn
    |> put_layout(conn.private.adminable_layout)
    |> put_view(conn.private.adminable_view_module)
    |> render("new.html", opts)
  end

  def create(conn, %{"schema" => schema, "data" => data}) do
    schema_module = conn.private.adminable_schemas[schema]

    new_schema = struct(schema_module)

    changeset = schema_module.create_changeset(new_schema, data)

    case conn.private.adminable_repo.insert(changeset) do
      {:ok, _created} ->
        conn
        |> put_flash(:info, "#{String.capitalize(schema)} created!")
        |> redirect(to: Adminable.Router.Helpers.admin_path(conn, :index, schema))

      {:error, changeset} ->
        opts = [
          changeset: changeset,
          schema_module: schema_module,
          schema: schema
        ]

        conn
        |> put_flash(:error, "#{String.capitalize(schema)} failed to create!")
        |> put_status(:unprocessable_entity)
        |> put_layout(conn.private.adminable_layout)
        |> put_view(conn.private.adminable_view_module)
        |> render("new.html", opts)
    end
  end

  def edit(conn, %{"schema" => schema, "pk" => pk}) do
    schema_module = conn.private.adminable_schemas[schema]

    model =
      schema_module.__schema__(:associations)
      |> Enum.reduce(conn.private.adminable_repo.get(schema_module, pk), fn a, m ->
        conn.private.adminable_repo.preload(m, a)
      end)

    opts = [
      changeset: schema_module.edit_changeset(model, %{}),
      schema_module: schema_module,
      schema: schema,
      pk: pk
    ]

    conn
    |> put_layout(conn.private.adminable_layout)
    |> put_view(conn.private.adminable_view_module)
    |> render("edit.html", opts)
  end

  def update(conn, %{"schema" => schema, "pk" => pk, "data" => data}) do
    schema_module = conn.private.adminable_schemas[schema]

    item = conn.private.adminable_repo.get!(schema_module, pk)

    changeset = schema_module.edit_changeset(item, data)

    case conn.private.adminable_repo.update(changeset) do
      {:ok, _updated_model} ->
        conn
        |> put_flash(:info, "#{String.capitalize(schema)} ID #{pk} updated!")
        |> redirect(to: Adminable.Router.Helpers.admin_path(conn, :index, schema))

      {:error, changeset} ->
        opts = [
          changeset: changeset,
          schema_module: schema_module,
          schema: schema,
          pk: pk
        ]

        conn
        |> put_flash(:error, "#{String.capitalize(schema)} ID #{pk} failed to update!")
        |> put_status(:unprocessable_entity)
        |> put_layout(conn.private.adminable_layout)
        |> put_view(conn.private.adminable_view_module)
        |> render("edit.html", opts)
    end
  end
end
