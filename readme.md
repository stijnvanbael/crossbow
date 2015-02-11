Dart Crossbow
=============

Crossbow is a library for building applications as a series of pipelines.

Crossbow principles:

  * Functions should never block
  * Code should be terse
  * Futures should be hidden
  * Defaults should be sensible
  * Prefer streams over lists

Example:

    HttpServer.get('/user/{username}/trips/{date}')
        .select(from: Trip,
            where: (headers, body) =>
                path('user.username').equalTo(headers.path('username')
                    .and(path('date').equalTo(headers.path('date')))
        .convert(to: Json)
        .join(by: (headers, body) => headers['request'],
            as: JsonArray)
        .start();

The example above will accept HTTP connections on port 8080 on the specified URL with placeholders 'username' and 'date'. It will
then perform a query for the type Trip using the path parameters. The results of the query will be streamed and
converted to JSON as they come in. Then the results will be joined again by the request and streamed to the response
as a JSON array.