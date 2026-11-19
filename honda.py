import os
from html import escape

from flask import Flask, request

app = Flask(__name__)


@app.route("/")
def hello():
    name = escape(request.args.get("name", "World"))
    return (
        f"<h1>Hello, {name}!</h1>"
        "<p>Hitechcity gachibowli ameerpet!</p>"
        "<p>Google cloud storage!</p>"
    )


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 8080)))
